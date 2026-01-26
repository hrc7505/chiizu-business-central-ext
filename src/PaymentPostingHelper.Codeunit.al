codeunit 50143 "Chiizu Payment Posting Helper"
{
    procedure PostBatch(Batch: Record "Chiizu Payment Batch")
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
    begin
        // Safety checks
        if Batch."Total Amount" <= 0 then
            Error('Payment amount must be greater than zero.');

        if Batch."Vendor No." = '' then
            Error('Vendor No. is missing.');

        /* if Batch."Bank Account No." = '' then
            Error('Bank Account No. is missing.'); */

        GenJnlLine.Init();

        // Required identifiers
        GenJnlLine.Validate("Journal Template Name", 'GENERAL');
        GenJnlLine.Validate("Journal Batch Name", 'DEFAULT');
        GenJnlLine."Line No." := GetNextLineNo('GENERAL', 'DEFAULT');

        // Document info
        GenJnlLine.Validate("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.Validate("Document No.", Batch."Batch Id");
        GenJnlLine.Validate("Posting Date", Today());

        // Vendor (payment FROM company)
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Vendor);
        GenJnlLine.Validate("Account No.", Batch."Vendor No.");

        // Bank (money goes OUT from bank)
        GenJnlLine.Validate(
            "Bal. Account Type",
            GenJnlLine."Bal. Account Type"::"Bank Account"
        );
        GenJnlLine.Validate(
            "Bal. Account No.",
           'CHECKING'  // todo: Hardcoded for now; later from setup or batch
        );

        // ✅ MUST be POSITIVE
        GenJnlLine.Validate(Amount, Batch."Total Amount");

        // Optional but recommended
        GenJnlLine."External Document No." := Batch."Payment Reference";

        GenJnlLine.Insert(true);

        // Post the journal
        GenJnlPost.Run(GenJnlLine);
    end;

    local procedure GetNextLineNo(TemplateName: Code[10]; BatchName: Code[10]): Integer
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.Reset();
        GenJnlLine.SetRange("Journal Template Name", TemplateName);
        GenJnlLine.SetRange("Journal Batch Name", BatchName);

        if GenJnlLine.FindLast() then
            exit(GenJnlLine."Line No." + 10000)
        else
            exit(10000);
    end;

}
