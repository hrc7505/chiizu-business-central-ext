page 50101 "Chiizu Payments"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Vendor Ledger Entry";
    Caption = 'Chiizu — Pay Invoices';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Document No."; Rec."Document No.") { }
                field("Vendor No."; Rec."Vendor No.") { }
                field("Remaining Amount"; Rec."Remaining Amount") { }
                field("Chiizu Paid"; Rec."Chiizu Paid") { }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(PayWithChiizu)
            {
                ApplicationArea = All;
                Caption = 'Pay Selected Invoices';
                Image = Payment;

                trigger OnAction()
                var
                    SelectedEntries: Record "Vendor Ledger Entry";
                    PaymentService: Codeunit "Chiizu Payment Service";
                    InvoiceCount: Integer;
                begin
                    CurrPage.SetSelectionFilter(SelectedEntries);

                    if SelectedEntries.IsEmpty() then
                        Error('Please select at least one invoice to pay.');

                    InvoiceCount := SelectedEntries.Count();

                    // ✅ ONE bulk call
                    PaymentService.PayVendorInvoicesBulk(SelectedEntries);

                    // ✅ End transaction so UI message is shown
                    Commit();

                    Message(
                        '%1 invoice(s) successfully submitted for payment via Chiizu.',
                        InvoiceCount
                    );

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
