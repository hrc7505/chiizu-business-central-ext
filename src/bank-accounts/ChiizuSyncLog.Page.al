namespace Chiizu.BankAccounts;

page 1000012 "Chiizu Sync Log"
{
    PageType = List;
    SourceTable = "Chiizu Sync Log";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    Caption = 'Chiizu Sync Log';
    ApplicationArea = All;
    UsageCategory = History;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Sync DateTime"; Rec."Sync DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time when the sync was performed.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = this.StatusStyle;
                    ToolTip = 'Status of the sync operation.';
                }
                field(Message; Rec.Message)
                {
                    ApplicationArea = All;
                    ToolTip = 'Detailed message for the sync log entry.';
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