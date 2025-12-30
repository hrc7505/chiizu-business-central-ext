pageextension 50101 "Chiizu Posted Purch Inv Ext" extends "Posted Purchase Invoices"
{
    Caption = 'Chiizu | Posted Purchase Invoices';

    layout
    {
        modify("No.")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Vendor Invoice No.")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Buy-from Vendor No.")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Buy-from Vendor Name")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Currency Code")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify(Amount)
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Amount Including VAT")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Location Code")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("No. Printed")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Due Date")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify("Remaining Amount")
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify(Closed)
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify(Cancelled)
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }
        modify(Corrective)
        {
            Visible = true;
            ApplicationArea = Basic, Suite;

        }

        addafter("Remaining Amount")
        {
            field("Chiizu Paid"; IsChiizuPaid())
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this invoice was paid via Chiizu.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(PayWithChiizu)
            {
                Caption = 'Pay with Chiizu';
                Image = Payment;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    VendLedgEntry: Record "Vendor Ledger Entry";
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    VendLedgEntry.SetRange(
                        "Document Type",
                        VendLedgEntry."Document Type"::Invoice
                    );
                    VendLedgEntry.SetRange("Document No.", Rec."No.");
                    VendLedgEntry.SetRange(Open, true);

                    if not VendLedgEntry.FindFirst() then
                        Error('No open vendor ledger entry found.');

                    PaymentService.PayVendorLedgerEntry(VendLedgEntry);
                end;
            }

            action(ScheduleChiizuPayment)
            {
                Caption = 'Schedule Payment';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SchedulePage: Page "Chiizu Schedule Payment";
                    PurchHeader: Record "Purchase Header";
                begin
                    PurchHeader.Get(
                        PurchHeader."Document Type"::Invoice,
                        Rec."No."
                    );

                    SchedulePage.SetPurchaseHeader(PurchHeader);
                    SchedulePage.RunModal();
                end;
            }
        }
    }

    // -----------------------------
    // Helpers
    // -----------------------------
    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");

        exit(false);
    end;
}
