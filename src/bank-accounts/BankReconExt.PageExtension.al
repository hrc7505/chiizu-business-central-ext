pageextension 50106 "Chiizu Bank Recon Ext" extends "Bank Acc. Reconciliation"
{
    actions
    {
        addlast(processing)
        {
            action(FetchChiizuTransactions)
            {
                Caption = 'Fetch Chiizu Transactions';
                Image = ImportDatabase;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Pull the latest transaction history from the Chiizu API into this reconciliation.';

                trigger OnAction()
                var
                    SetupMgmt: Codeunit "Chiizu Setup Management";
                begin
                    // This calls the logic to map API JSON to the Statement Lines
                    SetupMgmt.ImportToBankReconciliation(Rec);
                end;
            }
        }
    }
}