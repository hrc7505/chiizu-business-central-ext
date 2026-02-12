pageextension 50105 "Chiizu Bank Acc Card Ext" extends "Bank Account Card"
{
    layout
    {
        addafter(Balance)
        {
            field("Chiizu Remote Balance"; Rec."Chiizu Remote Balance")
            {
                ApplicationArea = All;
                ToolTip = 'Shows the real-time balance fetched from Chiizu.';
                Style = Ambiguous; // Makes the value stand out
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(SyncChiizuBalance)
            {
                Caption = 'Sync Chiizu Balance';
                Image = Refresh;
                ApplicationArea = All;
                ToolTip = 'Fetch the latest balance from Chiizu for this account.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    SetupMgmt: Codeunit "Chiizu Setup Management";
                begin
                    // Now SetupMgmt HAS the procedure we added in Step 1
                    Rec."Chiizu Remote Balance" := SetupMgmt.GetRemoteAccountBalance(Rec."No.");
                    Rec.Modify(true);
                    Message('Balance updated from Chiizu.');
                end;
            }
        }
    }
}