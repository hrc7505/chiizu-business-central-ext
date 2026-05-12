codeunit 50119 "Chiizu Statement Import"
{
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        BankAccRecon: Record "Bank Acc. Reconciliation";
        RecRef: RecordRef;
        ApiClient: Codeunit "Chiizu API Client"; // 🔹 Centralized Client
        ReconLine: Record "Bank Acc. Reconciliation Line";
        DuplicateCheck: Record "Bank Acc. Reconciliation Line";
        ResponseJson: JsonObject;
        TxnArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        TxnId: Text;
        i: Integer;
        NextLineNo: Integer;
        BankAccNo: Code[20];
    begin
        // 1. THE UNIVERSAL UNPACKER
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

        // 2. FETCH AND PARSE USING THE API CLIENT
        // Auth, Base URL, /api, and Error handling are all done for us!
        ResponseJson := ApiClient.GetJson('/funding-accounts/' + BankAccNo + '/transactions');

        if not ResponseJson.Get('transactions', Token) then begin
            Message('No transactions array found.');
            exit;
        end;

        TxnArray := Token.AsArray();
        if TxnArray.Count() = 0 then begin
            Message('No transactions to import.');
            exit;
        end;

        // 3. FIND LAST LINE NO
        ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
        ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");
        if ReconLine.FindLast() then
            NextLineNo := ReconLine."Statement Line No." + 10000
        else
            NextLineNo := 10000;

        // 4. PARSE AND INSERT
        for i := 0 to TxnArray.Count() - 1 do begin
            TxnArray.Get(i, Token);
            ItemObj := Token.AsObject();
            TxnId := ApiClient.GetJsonString(ItemObj, 'id'); // 🔹 Reused Helper!

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

                ReconLine.Validate("Transaction Date", ApiClient.GetJsonDate(ItemObj, 'date')); // 🔹 Reused Helper!
                ReconLine.Description := CopyStr(ApiClient.GetJsonString(ItemObj, 'description'), 1, MaxStrLen(ReconLine.Description));
                ReconLine.Validate("Statement Amount", ApiClient.GetJsonDecimal(ItemObj, 'amount')); // 🔹 Reused Helper!
                ReconLine."Transaction ID" := CopyStr(TxnId, 1, MaxStrLen(ReconLine."Transaction ID"));

                ReconLine.Insert(true);
                NextLineNo += 10000;
            end;
        end;

        Message('Chiizu sync complete. Imported %1 transactions.', TxnArray.Count());
    end;
}