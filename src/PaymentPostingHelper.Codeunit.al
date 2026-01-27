codeunit 50143 "Chiizu Payment Posting Helper"
{
    procedure PostBatch(var Batch: Record "Chiizu Payment Batch")
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
        InvoiceStatus: Record "Chiizu Invoice Status";
        VLE: Record "Vendor Ledger Entry";
        AmountToPay: Decimal;
    begin
        EnsureJournalExists();

        InvoiceStatus.SetRange("Batch Id", Batch."Batch Id");
        if not InvoiceStatus.FindSet() then
            Error('No invoices found for batch %1', Batch."Batch Id");

        repeat
            // 🔎 Resolve Vendor Ledger Entry
            VLE.Reset();
            VLE.SetRange("Document Type", VLE."Document Type"::Invoice);
            VLE.SetRange("Document No.", InvoiceStatus."Invoice No.");
            VLE.SetRange("Vendor No.", Batch."Vendor No.");
            VLE.SetRange(Open, true);

            if not VLE.FindFirst() then
                Error('Open vendor ledger entry not found for invoice %1', InvoiceStatus."Invoice No.");

            VLE.CalcFields("Remaining Amount");
            AmountToPay := Abs(VLE."Remaining Amount");

            if AmountToPay <= 0 then
                Error('Invoice %1 has no remaining amount.', InvoiceStatus."Invoice No.");

            // 🧾 Create payment line
            GenJnlLine.Init();
            GenJnlLine.Validate("Journal Template Name", 'GENERAL');
            GenJnlLine.Validate("Journal Batch Name", 'DEFAULT');
            GenJnlLine."Line No." := GetNextLineNo();

            GenJnlLine.Validate("Document No.", Batch."Batch Id");
            GenJnlLine.Validate("Document Type", GenJnlLine."Document Type"::Payment);
            GenJnlLine.Validate("Posting Date", Today());

            // Vendor
            GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Vendor);
            GenJnlLine.Validate("Account No.", Batch."Vendor No.");

            // Bank
            GenJnlLine.Validate("Bal. Account Type", GenJnlLine."Bal. Account Type"::"Bank Account");
            GenJnlLine.Validate("Bal. Account No.", 'CHECKING');

            // ✅ Correct amount
            GenJnlLine.Validate(Amount, AmountToPay);

            // ✅ Correct application
            GenJnlLine."Applies-to Doc. Type" := GenJnlLine."Applies-to Doc. Type"::Invoice;
            GenJnlLine."Applies-to Doc. No." := InvoiceStatus."Invoice No.";

            GenJnlLine."External Document No." := Batch."Payment Reference";

            GenJnlLine.Insert(true);
            GenJnlPost.Run(GenJnlLine);

        until InvoiceStatus.Next() = 0;
    end;

    local procedure GetNextLineNo(): Integer
    var
        Line: Record "Gen. Journal Line";
    begin
        Line.SetRange("Journal Template Name", 'GENERAL');
        Line.SetRange("Journal Batch Name", 'DEFAULT');
        if Line.FindLast() then
            exit(Line."Line No." + 10000);
        exit(10000);
    end;

    local procedure EnsureJournalExists()
    var
        Template: Record "Gen. Journal Template";
        Batch: Record "Gen. Journal Batch";
    begin
        if not Template.Get('GENERAL') then
            Error('General Journal Template GENERAL is missing.');

        Batch.SetRange("Journal Template Name", 'GENERAL');
        Batch.SetRange(Name, 'DEFAULT');
        if not Batch.FindFirst() then
            Error('General Journal Batch DEFAULT is missing.');
    end;

}
