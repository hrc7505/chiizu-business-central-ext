page 50101 "Chiizu Purchase Invoices"
{
    PageType = List;
    SourceTable = "Purch. Inv. Header";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Chiizu Purchase Invoices';
    InstructionalText = 'Select an invoice to see details in the Info pane.';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }

                field("Buy-from Vendor No."; Rec."Buy-from Vendor No.")
                {
                    ApplicationArea = All;
                }

                field("Buy-from Vendor Name"; Rec."Buy-from Vendor Name")
                {
                    ApplicationArea = All;
                }

                field("Vendor Invoice No."; Rec."Vendor Invoice No.")
                {
                    ApplicationArea = All;
                }

                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                }

                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                }

                // ✅ Chiizu status (from custom table)
                field("Chiizu Paid"; IsChiizuPaid())
                {
                    ApplicationArea = All;
                }
            }
        }

        // =================================================
        // RIGHT-HAND DETAILS / FACTBOX PANE
        // =================================================
        area(factboxes)
        {
            systempart(Links; Links) { }
            systempart(Notes; Notes) { }

            // ✅ Correct Incoming Document FactBox (POSTED invoices)
            part(IncomingDoc; "Incoming Doc. Attach. FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "Document No." = field("No.");
            }

            // ✅ Correct Vendor FactBox
            part(VendorDetails; "Vendor Details FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = field("Buy-from Vendor No.");
            }
        }

    }

    actions
    {
        area(processing)
        {
            action(PayWithChiizu)
            {
                Caption = 'Pay with Chiizu';
                Image = Payment;
                ApplicationArea = All;

                trigger OnAction()
                var
                    PurchInvHeader: Record "Purch. Inv. Header";
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    CurrPage.SetSelectionFilter(PurchInvHeader);

                    if PurchInvHeader.IsEmpty() then
                        Error('Please select at least one purchase invoice.');

                    PaymentService.PayPurchaseInvoicesBulk(PurchInvHeader);

                    Message('Selected invoice(s) sent to Chiizu successfully.');
                end;
            }
        }
    }

    // =================================================
    // LOCAL HELPERS
    // =================================================
    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");

        exit(false);
    end;
}
