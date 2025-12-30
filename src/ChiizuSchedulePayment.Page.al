page 50120 "Chiizu Schedule Payment"
{
    PageType = Card;
    SourceTable = "Chiizu Scheduled Payment";
    SourceTableTemporary = true;

    Caption = 'Schedule Payment (Chiizu)';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Invoice)
            {
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(Scheduling)
            {
                field("Scheduled Date"; Rec."Scheduled Date")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Schedule)
            {
                Caption = 'Schedule';
                Image = Calendar;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    ValidateData();

                    Rec.Status := Rec.Status::Scheduled;
                    Rec.Insert(true);

                    Message(
                        'Payment for invoice %1 scheduled for %2.',
                        Rec."Invoice No.",
                        Rec."Scheduled Date"
                    );

                    CurrPage.Close();
                end;
            }

            action(Cancel)
            {
                Caption = 'Cancel';
                Image = Cancel;

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    // -------------------------------------------------
    // CALLED FROM PAGE EXTENSION
    // -------------------------------------------------
    procedure SetPurchaseHeader(PurchHeader: Record "Purchase Header")
    var
        VendLedgEntry: Record "Vendor Ledger Entry";
    begin
        Rec.Reset();
        Rec.DeleteAll();

        // 🔍 Find the POSTED invoice ledger entry
        VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
        VendLedgEntry.SetRange("Document No.", PurchHeader."No.");
        VendLedgEntry.SetRange(Open, true);

        if not VendLedgEntry.FindFirst() then
            Error(
                'Invoice %1 is not posted or has no remaining amount.',
                PurchHeader."No."
            );

        Rec.Init();
        Rec."Invoice No." := VendLedgEntry."Document No.";
        Rec."Vendor No." := VendLedgEntry."Vendor No.";
        Rec.Amount := VendLedgEntry."Remaining Amount"; // ✅ MOST ACCURATE
        Rec."Scheduled Date" := Today;
        Rec.Status := Rec.Status::Open;

        // ⭐ THIS IS WHY DATA SHOWS ON CARD
        Rec.Insert();
    end;

    local procedure ValidateData()
    begin
        if Rec.Amount <= 0 then
            Error('Invoice has no remaining payable amount.');

        if Rec."Scheduled Date" < Today then
            Error('Scheduled date must be today or later.');
    end;
}
