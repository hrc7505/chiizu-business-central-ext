codeunit 50143 "Chiizu Payment Posting Helper"
{
    procedure PostPayment(Batch: Record "Chiizu Payment Batch")
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
    begin
        // -------------------------------
        // Safety checks
        // -------------------------------
        if Batch."Total Amount" <= 0 then
            Error('Payment amount must be greater than zero.');

        if Batch."Vendor No." = '' then
            Error('Vendor No. is missing.');

        if Batch."Invoice No." = '' then
            Error('Invoice No. is missing in payment batch %1.', Batch."Batch Id");

        // -------------------------------
        // Init Payment Journal Line
        // -------------------------------
        GenJnlLine.Init();
        GenJnlLine.Validate("Journal Template Name", 'PAYMENT');
        GenJnlLine.Validate("Journal Batch Name", 'PMT REG');
        GenJnlLine."Line No." := GetNextLineNo('PAYMENT', 'PMT REG');

        // -------------------------------
        // Document info
        // -------------------------------
        GenJnlLine.Validate("Posting Date", Today());
        GenJnlLine.Validate("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.Validate("Document No.", Batch."Batch Id");

        // -------------------------------
        // Vendor (who we pay)
        // -------------------------------
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Vendor);
        GenJnlLine.Validate("Account No.", Batch."Vendor No.");

        // -------------------------------
        // Bank (money goes out)
        // -------------------------------
        GenJnlLine.Validate(
            "Bal. Account Type",
            GenJnlLine."Bal. Account Type"::"Bank Account"
        );
        GenJnlLine.Validate(
            "Bal. Account No.",
            'CHECKING' // TODO: move to setup later
        );

        // -------------------------------
        // Amount (PAYMENT MUST BE NEGATIVE)
        // -------------------------------
        GenJnlLine.Validate(Amount, -Batch."Total Amount");

        // -------------------------------
        // 🔥 THIS IS THE KEY PART 🔥
        // Auto-application setup
        // -------------------------------
        GenJnlLine.Validate(
            "Applies-to Doc. Type",
            GenJnlLine."Applies-to Doc. Type"::Invoice
        );
        GenJnlLine.Validate("Applies-to Doc. No.", Batch."Invoice No.");

        // Optional but useful
        GenJnlLine."External Document No." := Batch."Payment Reference";
        GenJnlLine.Description := 'Chiizu payment';

        // -------------------------------
        // Insert + Post
        // -------------------------------
        GenJnlLine.Insert(true);
        GenJnlPostLine.RunWithCheck(GenJnlLine);

        // 🎉 DONE
        // BC will now:
        // - Create Vendor Ledger Entry
        // - Apply payment to invoice
        // - Close invoice if fully paid
        // - Update Remaining Amount
    end;

    // ----------------------------------------------------
    // Helper: Next Line No.
    // ----------------------------------------------------
    local procedure GetNextLineNo(
        TemplateName: Code[10];
        BatchName: Code[10]
    ): Integer
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
