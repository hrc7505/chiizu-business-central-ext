codeunit 50119 "Chiizu Statement Import"
{
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        BankAccRecon: Record "Bank Acc. Reconciliation";
        RecRef: RecordRef;
        ChiizuSetup: Record "Chiizu Setup";
        ReconLine: Record "Bank Acc. Reconciliation Line";
        DuplicateCheck: Record "Bank Acc. Reconciliation Line";
        Client: HttpClient;
        ResponseMessage: HttpResponseMessage;
        ResponseText: Text;
        ResponseJson: JsonObject; // 🔹 Re-added to read the root object
        TxnArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        TxnId: Text;
        i: Integer;
        NextLineNo: Integer;
        BankAccNo: Code[20];
        OutStr: OutStream;
    begin
        // 1. THE UNIVERSAL UNPACKER
        if not RecRef.Get(Rec."Related Record") then
            Error('Could not find the related screen record.');

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
                    if not BankAccRecon.FindLast() then
                        Error('Could not find an open Bank Reconciliation for account %1.', BankAccNo);
                end;
            Database::"Bank Acc. Reconciliation Line":
                begin
                    // 🔹 FIX: Use SetRange instead of Get() to safely handle Variant types!
                    BankAccNo := RecRef.Field(2).Value;
                    BankAccRecon.SetRange("Statement Type", RecRef.Field(1).Value);
                    BankAccRecon.SetRange("Bank Account No.", BankAccNo);
                    BankAccRecon.SetRange("Statement No.", RecRef.Field(3).Value);
                    if not BankAccRecon.FindFirst() then
                        Error('Could not find the Bank Reconciliation Header.');
                end;
            else
                Error('Microsoft Engine passed unexpected Table ID: %1.', RecRef.Number);
        end;

        // 2. AUTHENTICATE
        if not ChiizuSetup.Get('SETUP') then Error('Chiizu not configured.');
        ChiizuSetup.TestField("API Base URL");
        ChiizuSetup.TestField("API Key");
        Client.DefaultRequestHeaders().Add('Authorization', 'Bearer ' + ChiizuSetup."API Key");

        // 3. FETCH AND PARSE THE DATA (THE FIX!)
        // 🔹 Hardcoded /api into the route string!
        if not Client.Get(ChiizuSetup."API Base URL" + '/api/funding-accounts/' + BankAccNo + '/transactions', ResponseMessage) then
            Error('Could not connect to API.');

        ResponseMessage.Content().ReadAs(ResponseText);

        if not ResponseMessage.IsSuccessStatusCode() then
            Error('API Failed. Status Code: %1.\nRaw Response:\n%2', ResponseMessage.HttpStatusCode(), ResponseText);

        // 🔹 1. Parse the root payload into a JsonObject
        if not ResponseJson.ReadFrom(ResponseText) then
            Error('Failed to parse JSON Object. Received:\n%1', ResponseText);

        // 🔹 2. Extract the "transactions" array from inside the object
        if not ResponseJson.Get('transactions', Token) then begin
            Message('No transactions array found in the JSON payload.');
            exit;
        end;

        // 🔹 3. Convert that token into our working array
        TxnArray := Token.AsArray();

        if TxnArray.Count() = 0 then begin
            Message('No transactions to import.');
            exit;
        end;

        // 4. FIND LAST LINE NO
        ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
        ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");
        if ReconLine.FindLast() then
            NextLineNo := ReconLine."Statement Line No." + 10000
        else
            NextLineNo := 10000;

        // 5. PARSE AND INSERT
        for i := 0 to TxnArray.Count() - 1 do begin
            TxnArray.Get(i, Token);
            ItemObj := Token.AsObject();
            TxnId := GetJsonValue(ItemObj, 'id');

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

                ReconLine.Validate("Transaction Date", GetJsonDateValue(ItemObj, 'date'));
                ReconLine.Description := CopyStr(GetJsonValue(ItemObj, 'description'), 1, MaxStrLen(ReconLine.Description));
                ReconLine.Validate("Statement Amount", GetJsonDecimalValue(ItemObj, 'amount'));
                ReconLine."Transaction ID" := CopyStr(TxnId, 1, MaxStrLen(ReconLine."Transaction ID"));

                ReconLine.Insert(true);
                NextLineNo += 10000;
            end;
        end;

        // 6. FINISH AND EXIT
        // Leave the Blob completely empty so Microsoft's engine quietly stops!
        Message('Chiizu sync complete. Imported %1 transactions.', TxnArray.Count());
    end;

    // --- HELPER FUNCTIONS ---
    local procedure GetJsonValue(Obj: JsonObject; Property: Text): Text
    var
        Token: JsonToken;
    begin
        if Obj.Get(Property, Token) then
            if not Token.AsValue().IsNull() then exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure GetJsonDateValue(Obj: JsonObject; Property: Text): Date
    var
        Token: JsonToken;
        ResultDate: Date;
    begin
        if Obj.Get(Property, Token) then
            if not Token.AsValue().IsNull() then
                if Evaluate(ResultDate, Token.AsValue().AsText()) then exit(ResultDate);
        exit(0D);
    end;

    local procedure GetJsonDecimalValue(Obj: JsonObject; Property: Text): Decimal
    var
        Token: JsonToken;
        ResultDec: Decimal;
    begin
        if Obj.Get(Property, Token) then
            if not Token.AsValue().IsNull() then
                if Evaluate(ResultDec, Token.AsValue().AsText()) then exit(ResultDec);
        exit(0.0);
    end;
}