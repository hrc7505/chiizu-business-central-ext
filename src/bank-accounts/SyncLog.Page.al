page 50112 "Chiizu Sync Log"
{
    PageType = List;
    SourceTable = "Chiizu Sync Log";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    Caption = 'Chiizu Sync Log';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Sync DateTime"; Rec."Sync DateTime")
                {
                    ApplicationArea = All;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
                field(Message; Rec.Message)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec.Status = Rec.Status::Success then
            StatusStyle := 'Favorable'
        else
            StatusStyle := 'Unfavorable';
    end;
}