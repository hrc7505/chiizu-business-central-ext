codeunit 50108 "Chiizu Setup Management"
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
        GetSetup(Setup);

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
        EnsureConnected();
        ResponseJson := ApiClient.GetJson('/funding-accounts');

        if not ResponseJson.Get('accounts', Token) then exit;
        AccountArray := Token.AsArray();

        for i := 0 to AccountArray.Count() - 1 do begin
            AccountArray.Get(i, Token);
            ItemObj := Token.AsObject();

            TempAcc.Init();
            TempAcc."Account Id" := GetJsonValue(ItemObj, 'id');
            TempAcc.Name := GetJsonValue(ItemObj, 'name');
            TempAcc."Account Number" := GetJsonValue(ItemObj, 'accountNumber');
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

            if GetJsonValue(ItemObj, 'id') = BankAcc."No." then begin
                BankAcc."Chiizu Remote Balance" := GetJsonDecimalValue(ItemObj, 'balance');
                BankAcc.Modify();
                exit;
            end;
        end;
    end;

    procedure ImportToBankReconciliation(BankAccRecon: Record "Bank Acc. Reconciliation")
    var
        ApiClient: Codeunit "Chiizu API Client";
        ReconLine: Record "Bank Acc. Reconciliation Line";
        DuplicateCheck: Record "Bank Acc. Reconciliation Line";
        ResponseJson: JsonObject;
        TxnArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        TxnId: Text;
        i: Integer;
        NextLineNo: Integer;
    begin
        // 1. Fetch transactions for the specific bank account from the API
        ResponseJson := ApiClient.GetJson('/funding-accounts/' + BankAccRecon."Bank Account No." + '/transactions');
        if not ResponseJson.Get('transactions', Token) then exit;
        TxnArray := Token.AsArray();

        // 2. Determine the next available Line No. within this specific statement
        ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
        ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");
        if ReconLine.FindLast() then
            NextLineNo := ReconLine."Statement Line No." + 10000
        else
            NextLineNo := 10000;

        // 3. Process each transaction from the JSON array
        for i := 0 to TxnArray.Count() - 1 do begin
            TxnArray.Get(i, Token);
            ItemObj := Token.AsObject();
            TxnId := GetJsonValue(ItemObj, 'id');

            // 4. Duplicate Check: Search for this ID in the standard field
            DuplicateCheck.SetRange("Statement Type", BankAccRecon."Statement Type");
            DuplicateCheck.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
            DuplicateCheck.SetRange("Transaction ID", TxnId); // Uses standard Field 70

            if DuplicateCheck.IsEmpty then begin
                ReconLine.Init();
                ReconLine."Statement Type" := BankAccRecon."Statement Type";
                ReconLine."Bank Account No." := BankAccRecon."Bank Account No.";
                ReconLine."Statement No." := BankAccRecon."Statement No.";
                ReconLine."Statement Line No." := NextLineNo;

                // Use CopyStr to safely fit the API ID into the 50-character field
                ReconLine."Transaction ID" := CopyStr(TxnId, 1, MaxStrLen(ReconLine."Transaction ID"));
                ReconLine."Transaction Date" := GetJsonDateValue(ItemObj, 'date');
                ReconLine.Description := CopyStr(GetJsonValue(ItemObj, 'description'), 1, MaxStrLen(ReconLine.Description));
                ReconLine."Statement Amount" := GetJsonDecimalValue(ItemObj, 'amount');

                ReconLine.Insert();
                NextLineNo += 10000;
            end;
        end;
    end;

    // --- JSON HELPERS ---
    local procedure GetJsonDateValue(Obj: JsonObject; KeyName: Text): Date
    var
        Token: JsonToken;
        DateVar: Date;
    begin
        if Obj.Get(KeyName, Token) then
            if Evaluate(DateVar, CopyStr(Token.AsValue().AsText(), 1, 10)) then exit(DateVar);
    end;

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
}
