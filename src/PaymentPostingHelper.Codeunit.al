codeunit 50143 "Chiizu Payment Posting Helper"
{
    procedure PostBatch(Batch: Record "Chiizu Payment Batch")
    var
        BatchLine: Record "Chiizu Payment Batch Line";
    begin
        BatchLine.SetRange("Batch Id", Batch."Batch Id");

        if BatchLine.FindSet() then
            repeat
                PostSingleInvoice(BatchLine);
            until BatchLine.Next() = 0;
    end;

    local procedure PostSingleInvoice(Line: Record "Chiizu Payment Batch Line")
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
    begin
        GenJnlLine.Init();
        GenJnlLine.Validate("Journal Template Name", 'PAYMENTS');
        GenJnlLine.Validate("Journal Batch Name", 'DEFAULT');

        GenJnlLine.Validate("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Vendor);
        GenJnlLine.Validate("Account No.", Line."Vendor No.");

        GenJnlLine.Validate(Amount, -Line.Amount);
        GenJnlLine.Validate("Posting Date", Today());

        // 🔑 APPLY EXPLICITLY
        GenJnlLine.Validate("Applies-to Doc. Type",
            GenJnlLine."Applies-to Doc. Type"::Invoice);
        GenJnlLine.Validate("Applies-to Doc. No.", Line."Invoice No.");

        GenJnlLine.Insert(true);

        GenJnlPost.Run(GenJnlLine);
    end;
}
