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

            // ✅ Proper part control here
            /*   usercontrol(ChiizuPayments; "ChiizuPayments")
              {
                  ApplicationArea = All;
                  Visible = true;
              } */
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
                    VendLedgEntry: Record "Vendor Ledger Entry";
                    PaymentService: Codeunit "Chiizu Payment Service";
                    CountPaid: Integer;
                begin
                    // Apply selection filter
                    CurrPage.SetSelectionFilter(VendLedgEntry);

                    if VendLedgEntry.IsEmpty() then
                        Error('Please select at least one invoice to pay.');

                    if VendLedgEntry.FindSet() then
                        repeat
                            // Safety checks
                            if VendLedgEntry."Remaining Amount" < 0 then
                                Error(
                                    'Invoice %1 has no remaining amount.',
                                    VendLedgEntry."Document No."
                                );

                            if VendLedgEntry."Chiizu Paid" then
                                Error(
                                    'Invoice %1 is already paid via Chiizu.',
                                    VendLedgEntry."Document No."
                                );

                            // ✅ Initiate payment
                            PaymentService.PayVendorInvoice(VendLedgEntry);
                            CountPaid += 1;

                        until VendLedgEntry.Next() = 0;

                    Message('%1 invoice(s) paid successfully via Chiizu.', CountPaid);
                end;
            }
        }
    }
}
