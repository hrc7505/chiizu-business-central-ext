namespace Chiizu.Installation;

using Chiizu;
using Chiizu.BankAccounts;
using Chiizu.Utils;
using Microsoft.Bank.BankAccount;
using Microsoft.Bank.Setup;
using System.IO;

codeunit 1000008 "Chiizu Setup Management"
{
    // --- SETUP & CONNECTION ---
    procedure GetSetup(var Setup: Record "Chiizu Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('Chiizu setup is not initialized.');
    end;

    procedure EnsureConnected(): Record "Chiizu Setup"
    var
        Setup: Record "Chiizu Setup";
    begin
        // Use your existing GetSetup to load the record
        this.GetSetup(Setup);

        if Setup."API Base URL" = '' then
            Error('Chiizu API Base URL is not configured.');

        if Setup."API Key" = '' then
            Error('Chiizu API Key is missing.');

        if Setup."Last Verified At" = 0DT then
            Error('Chiizu is not connected. Please verify connection.');

        exit(Setup); // 🔹 Return the validated record
    end;

    // --- INITIAL DISCOVERY (Manual Step) ---
    procedure FetchFundingAccounts(var TempAcc: Record "Chiizu Funding Account" temporary)
    var
        ApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        AccountArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        i: Integer;
    begin
        this.EnsureConnected();
        ResponseJson := ApiClient.GetJson('/funding-accounts');

        if not ResponseJson.Get('accounts', Token) then exit;
        AccountArray := Token.AsArray();

        for i := 0 to AccountArray.Count() - 1 do begin
            AccountArray.Get(i, Token);
            ItemObj := Token.AsObject();

            TempAcc.Init();
            TempAcc."Account Id" := CopyStr(this.GetJsonValue(ItemObj, 'id'), 1, MaxStrLen(TempAcc."Account Id"));
            TempAcc.Name := CopyStr(this.GetJsonValue(ItemObj, 'name'), 1, MaxStrLen(TempAcc.Name));
            TempAcc."Account Number" := CopyStr(this.GetJsonValue(ItemObj, 'accountNumber'), 1, MaxStrLen(TempAcc."Account Number"));
            TempAcc.Insert();
        end;
    end;

    // --- AUTOMATED SYNC LOGIC ---
    procedure UpdateRemoteBalance(var BankAcc: Record "Bank Account")
    var
        ApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        AccountArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        i: Integer;
    begin
        ResponseJson := ApiClient.GetJson('/funding-accounts');
        if not ResponseJson.Get('accounts', Token) then exit;
        AccountArray := Token.AsArray();

        for i := 0 to AccountArray.Count() - 1 do begin
            AccountArray.Get(i, Token);
            ItemObj := Token.AsObject();

            if this.GetJsonValue(ItemObj, 'id') = BankAcc."No." then begin
                BankAcc."Chiizu Remote Balance" := this.GetJsonDecimalValue(ItemObj, 'balance');
                BankAcc.Modify();
                exit;
            end;
        end;
    end;

    // Helper to get the balance specifically for a bank account ID
    procedure GetRemoteAccountBalance(AccountId: Code[50]): Decimal
    var
        ApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        AccountArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        i: Integer;
    begin
        ResponseJson := ApiClient.GetJson('/funding-accounts');
        if not ResponseJson.Get('accounts', Token) then exit(0);
        AccountArray := Token.AsArray();

        for i := 0 to AccountArray.Count() - 1 do begin
            AccountArray.Get(i, Token);
            ItemObj := Token.AsObject();
            if this.GetJsonValue(ItemObj, 'id') = AccountId then
                exit(this.GetJsonDecimalValue(ItemObj, 'balance'));
        end;
    end;

    // --- JSON HELPERS ---
    local procedure GetJsonValue(Obj: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then exit(Token.AsValue().AsText());
    end;

    local procedure GetJsonDecimalValue(Obj: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then exit(Token.AsValue().AsDecimal());
    end;

    procedure CreateBankAccountFromChiizuV2(ChiizuAcc: Record "Chiizu Funding Account" temporary)
    var
        BankAcc: Record "Bank Account";
        BankExImpSetup: Record "Bank Export/Import Setup";
        DataExchDef: Record "Data Exch. Def";
        ChiizuSetup: Record "Chiizu Setup";
    begin
        if not ChiizuSetup.Get('SETUP') then exit;
        if BankAcc.Get(ChiizuAcc."Account Id") then exit;
        ChiizuSetup.TestField("Default Bank Posting Group");

        // 1. DATA EXCH DEFINITION (STEP 1 OF MICROSOFT'S FLOW)
        if not DataExchDef.Get('CHIIZU') then begin
            DataExchDef.Init();
            DataExchDef.Code := 'CHIIZU';
            DataExchDef.Name := 'Chiizu API Sync';
            DataExchDef.Type := DataExchDef.Type::"Bank Statement Import";

            // 🔹 THE FIX: Put the REAL API here! It runs first, fetches the data, and writes the lines.
            DataExchDef."Ext. Data Handling Codeunit" := Codeunit::"Chiizu Statement Import"; // 1000019

            DataExchDef.Insert(true);
        end else begin
            // Self-healing to fix your current database
            DataExchDef."Ext. Data Handling Codeunit" := Codeunit::"Chiizu Statement Import"; // 1000019
            DataExchDef.Modify(true);
        end;

        // 2. BANK EXPORT/IMPORT SETUP (STEP 2 OF MICROSOFT'S FLOW)
        if not BankExImpSetup.Get('CHIIZU') then begin
            BankExImpSetup.Init();
            BankExImpSetup.Code := 'CHIIZU';
            BankExImpSetup.Name := 'Chiizu API Sync';
            BankExImpSetup.Direction := BankExImpSetup.Direction::Import;

            // 🔹 THE FIX: Put the EMPTY DUMMY here! It runs second and safely stops BC from crashing.
            BankExImpSetup."Processing Codeunit ID" := Codeunit::"Chiizu File Bypass"; // 1000020

            BankExImpSetup."Data Exch. Def. Code" := 'CHIIZU';
            BankExImpSetup.Insert(true);
        end else begin
            // Self-healing to fix your current database
            BankExImpSetup."Processing Codeunit ID" := Codeunit::"Chiizu File Bypass"; // 1000020
            BankExImpSetup."Data Exch. Def. Code" := 'CHIIZU';
            BankExImpSetup.Modify(true);
        end;

        // 3. CREATE BANK ACCOUNT
        BankAcc.Init();
        BankAcc."No." := CopyStr(ChiizuAcc."Account Id", 1, MaxStrLen(BankAcc."No."));
        BankAcc.Name := CopyStr(ChiizuAcc.Name, 1, MaxStrLen(BankAcc.Name));
        BankAcc."Bank Account No." := ChiizuAcc."Account Number";
        BankAcc."Currency Code" := ChiizuAcc."Currency Code";
        BankAcc.Validate("Bank Acc. Posting Group", ChiizuSetup."Default Bank Posting Group");
        BankAcc."Bank Statement Import Format" := 'CHIIZU';
        BankAcc.Insert(true);
    end;
}