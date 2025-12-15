pageextension 50102 "ChiizuRoleCenterExt" extends "Business Manager Role Center"
{
    actions
    {
        addlast(Sections)
        {
            group(ChiizuGroup)
            {
                Caption = 'Chiizu';
                action(OpenChiizuPayments)
                {
                    Caption = 'Chiizu Payments';
                    ApplicationArea = All;
                    RunObject = page "Chiizu Payments";
                }
            }
        }
    }
}
