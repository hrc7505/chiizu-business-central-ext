pageextension 50102 "ChiizuRoleCenterExt" extends "Business Manager Role Center"
{
    actions
    {
        addlast(Sections)
        {
            group(ChiizuGroup)
            {
                Caption = 'Chiizu';

                action(OpenPurchaseInvoices)
                {
                    Caption = 'Chiizu | Posted Purchase Invoices';
                    ApplicationArea = All;
                    RunObject = page "Posted Purchase Invoices";
                }
            }
        }
    }
}
