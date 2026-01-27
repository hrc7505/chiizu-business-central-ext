page 50103 "Chiizu Setup"
{
    PageType = Card;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Chiizu Setup';

    layout
    {
        area(content)
        {
            group(General)
            {
                field("API Base URL"; Rec."API Base URL") { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('CHIIZU') then begin
            Rec.Init();
            Rec."Primary Key" := 'CHIIZU';
            Rec.Insert();
        end;
    end;
}
