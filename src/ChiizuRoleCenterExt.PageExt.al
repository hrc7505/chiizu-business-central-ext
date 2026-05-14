namespace Chiizu;

using Microsoft.Finance.RoleCenters;
using Microsoft.Purchases.History;

pageextension 1000002 "ChiizuRoleCenterExt" extends "Business Manager Role Center"
{
    actions
    {
        addlast(Sections)
        {
            group(ChiizuGroup)
            {
                Caption = 'Chiizu';

                action(ChiizuOpenPurchaseInvoices)
                {
                    Caption = 'Chiizu | Posted Purchase Invoices';
                    ToolTip = 'Open the list of posted purchase invoices to view or process payments via Chiizu.';
                    ApplicationArea = All;
                    RunObject = page "Posted Purchase Invoices";
                }
            }
        }
    }
}
