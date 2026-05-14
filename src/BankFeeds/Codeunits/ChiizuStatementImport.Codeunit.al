namespace Chiizu.BankAccounts;

using Chiizu.Utils;
using Microsoft.Bank.BankAccount;
using Microsoft.Bank.Ledger;
using Microsoft.Bank.Reconciliation;
using System.IO;

codeunit 1000019 "Chiizu Statement Import"
{
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        BankAccRecon: Record "Bank Acc. Reconciliation";
        RecRef: RecordRef;
        BankAccNo: Code[20];
    begin
        // 1. THE UNIVERSAL UNPACKER (For the Manual Button)
        if not RecRef.Get(Rec."Related Record") then Error('Could not find the related screen record.');

        case RecRef.Number of
            Database::"Bank Acc. Reconciliation":
                begin
                    RecRef.SetTable(BankAccRecon);
                    BankAccNo := BankAccRecon."Bank Account No.";
                end;
            Database::"Bank Account":
                begin
                    BankAccNo := RecRef.Field(1).Value;
                    BankAccRecon.SetRange("Bank Account No.", BankAccNo);
                    if not BankAccRecon.FindLast() then Error('Could not find open Bank Rec for %1.', BankAccNo);
                end;
            Database::"Bank Acc. Reconciliation Line":
                begin
                    BankAccNo := RecRef.Field(2).Value;
                    BankAccRecon.SetRange("Statement Type", RecRef.Field(1).Value);
                    BankAccRecon.SetRange("Bank Account No.", BankAccNo);
                    BankAccRecon.SetRange("Statement No.", RecRef.Field(3).Value);
                    if not BankAccRecon.FindFirst() then Error('Could not find Bank Rec Header.');
                end;
            else
                Error('Microsoft Engine passed unexpected Table ID: %1.', RecRef.Number);
        end;

        // 2. PASS TO THE CORE ENGINE
        this.ImportTransactionsToRecon(BankAccRecon);
    end;

    // --- THE AUTOMATION TRIGGER (For Job Queues & Webhooks) ---
    procedure BackgroundSyncAccount(BankAccNo: Code[20])
    var
        BankAccRecon: Record "Bank Acc. Reconciliation";
    begin
        // 1. Check if an open draft reconciliation already exists
        BankAccRecon.SetRange("Statement Type", BankAccRecon."Statement Type"::"Bank Reconciliation");
        BankAccRecon.SetRange("Bank Account No.", BankAccNo);

        if not BankAccRecon.FindLast() then begin
            // 2. If no open draft exists, silently create a new one!
            BankAccRecon.Init();
            BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
            BankAccRecon."Bank Account No." := BankAccNo;
            BankAccRecon.Insert(true); // BC auto-assigns the "Statement No." here
        end;

        // 3. Pass to the Core Engine
        this.ImportTransactionsToRecon(BankAccRecon);
    end;

    // --- THE CORE ENGINE (Used by everything) ---
    local procedure ImportTransactionsToRecon(var BankAccRecon: Record "Bank Acc. Reconciliation")
    var
        ReconLine: Record "Bank Acc. Reconciliation Line";
        DuplicateCheck: Record "Bank Acc. Reconciliation Line";
        BankLedger: Record "Bank Account Ledger Entry";
        ApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        TxnArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        TxnId: Code[50];
        ApiUrl: Text;
        StartDateString: Text;
        LastSyncDate: Date;
        HasMorePages: Boolean;
        CurrentPage: Integer;
        TotalImported: Integer;
        NextLineNo: Integer;
        i: Integer;
    begin
        // 1. CALCULATE DELTA SYNC (Find the date of the last synced transaction)
        BankLedger.Reset();
        BankLedger.SetCurrentKey("Bank Account No.", "Posting Date");
        BankLedger.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        if BankLedger.FindLast() then
            LastSyncDate := BankLedger."Posting Date"
        else
            LastSyncDate := CalcDate('<-30D>', Today); // Fallback: Fetch last 30 days for new accounts

        // Format Date to strict YYYY-MM-DD for the API Query String
        StartDateString := Format(LastSyncDate, 0, '<Year4>-<Month,2>-<Day,2>');

        // 2. FIND STARTING LINE NUMBER
        ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
        ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");
        if ReconLine.FindLast() then
            NextLineNo := ReconLine."Statement Line No." + 10000
        else
            NextLineNo := 10000;

        // 3. THE PAGING LOOP
        HasMorePages := true;
        CurrentPage := 1; // Assuming your API starts at Page 1 (adjust to 0 if needed)
        TotalImported := 0;

        while HasMorePages do begin
            // Build dynamic URL with Paging and Delta parameters
            ApiUrl := '/funding-accounts/' + BankAccRecon."Bank Account No." + '/transactions' +
                      '?startDate=' + StartDateString +
                      '&page=' + Format(CurrentPage);

            ResponseJson := ApiClient.GetJson(ApiUrl);

            // If there's no transactions array, we reached the end. Break the loop.
            if not ResponseJson.Get('transactions', Token) then break;

            TxnArray := Token.AsArray();

            // If the array is empty, we reached the end of the pages. Break the loop.
            if TxnArray.Count() = 0 then break;

            // 4. PARSE AND INSERT THIS PAGE
            for i := 0 to TxnArray.Count() - 1 do begin
                TxnArray.Get(i, Token);
                ItemObj := Token.AsObject();
                TxnId := CopyStr(ApiClient.GetJsonString(ItemObj, 'id'), 1, MaxStrLen(TxnId));

                DuplicateCheck.Reset();
                DuplicateCheck.SetRange("Statement Type", BankAccRecon."Statement Type");
                DuplicateCheck.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
                DuplicateCheck.SetRange("Statement No.", BankAccRecon."Statement No.");
                DuplicateCheck.SetRange("Transaction ID", TxnId);

                if DuplicateCheck.IsEmpty then begin
                    ReconLine.Init();
                    ReconLine."Statement Type" := BankAccRecon."Statement Type";
                    ReconLine."Bank Account No." := BankAccRecon."Bank Account No.";
                    ReconLine."Statement No." := BankAccRecon."Statement No.";
                    ReconLine."Statement Line No." := NextLineNo;

                    ReconLine.Validate("Transaction Date", ApiClient.GetJsonDate(ItemObj, 'date'));
                    ReconLine.Description := CopyStr(ApiClient.GetJsonString(ItemObj, 'description'), 1, MaxStrLen(ReconLine.Description));
                    ReconLine.Validate("Statement Amount", ApiClient.GetJsonDecimal(ItemObj, 'amount'));
                    ReconLine."Transaction ID" := TxnId;

                    ReconLine.Insert(true);
                    NextLineNo += 10000;
                    TotalImported += 1; // Track successful inserts
                end;
            end;

            // 5. INCREMENT PAGE
            CurrentPage += 1;
        end;

        // 6. AUTO-FILL HEADER & EXIT
        // If the statement header date is blank, auto-fill it with the newest transaction date so BC doesn't show a popup
        if (TotalImported > 0) and (BankAccRecon."Statement Date" = 0D) then begin
            ReconLine.Reset();
            ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
            ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
            ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");
            if ReconLine.FindLast() then begin
                BankAccRecon.Validate("Statement Date", ReconLine."Transaction Date");
                BankAccRecon.Modify(true);
            end;
        end;

        // Only show message if called manually (GUI allowed)
        if GuiAllowed then
            if TotalImported = 0 then
                Message('No new transactions to import since %1.', LastSyncDate)
            else
                Message('Chiizu sync complete. Imported %1 new transactions.', TotalImported);
    end;
}