namespace Chiizu.Finalize;

using Microsoft.Purchases.History;

page 1000008 "Chiizu Finalize Invoice List"
{
    PageType = ListPart;
    SourceTable = "Purch. Inv. Header";
    SourceTableTemporary = true;
    Caption = 'Invoices to Pay';
    Editable = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = true;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Tooltip = 'Purchase invoice number.';
                }
                field("Buy-from Vendor Name"; Rec."Buy-from Vendor Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Tooltip = 'Vendor name for this purchase invoice.';
                }
                field("Remaining Amount"; Rec."Remaining Amount")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Tooltip = 'Remaining amount due on the purchase invoice.';
                }
                field("Amount Including VAT"; Rec."Amount Including VAT")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Tooltip = 'Total amount including VAT for the purchase invoice.';
                }
            }
        }
    }

    // 🛑 THE CRITICAL FIX: Overriding the standard delete trigger
    trigger OnDeleteRecord(): Boolean
    begin
        // Delete(false) skips the Table-level OnDelete trigger that causes your error
        Rec.Delete(false);

        // Refresh the parent page totals
        CurrPage.Update(false);

        // Return FALSE to tell BC "I have already handled the deletion, don't do it again"
        exit(false);
    end;

    procedure SetInvoices(InvoiceNos: List of [Code[20]])
    var
        RealPurchInv: Record "Purch. Inv. Header";
        InvNo: Code[20];
    begin
        Rec.Reset();
        Rec.DeleteAll();

        foreach InvNo in InvoiceNos do
            if RealPurchInv.Get(InvNo) then begin
                Rec.Init();
                Rec.TransferFields(RealPurchInv);
                // Use Insert(false) here as well just to be safe
                Rec.Insert(false);
            end;

        if Rec.FindFirst() then;
    end;

    procedure GetRemainingInvoiceNos(var ResultList: List of [Code[20]])
    begin
        Clear(ResultList);
        // We look at our temporary buffer to see what is left
        if Rec.FindSet() then
            repeat
                ResultList.Add(Rec."No.");
            until Rec.Next() = 0;
    end;
}