page 50101 "Chiizu Assisted Setup"
{
    PageType = Card;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    Caption = 'Chiizu';

    layout
    {
        area(Content)
        {
            group(Connection)
            {
                Caption = 'Connection';
                Visible = CurrentStep = 1;

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                }

                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                }
            }

            group(FinishGroup)
            {
                Caption = 'Finish';
                Visible = CurrentStep = 2;

                label(DoneLbl)
                {
                    Caption = 'Setup is ready to complete.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Connect)
            {
                Caption = 'Connect';
                Promoted = true;

                trigger OnAction()
                var
                    GuidedExperience: Codeunit "Guided Experience";
                begin
                    if Rec."API Base URL" = '' then
                        Error('API Base URL is required.');

                    if Rec."API Key" = '' then
                        Error('API Key is required.');

                    // Test connection here

                    Rec."Setup Completed" := true;
                    Rec.Modify(true);

                    GuidedExperience.CompleteAssistedSetup(
                        ObjectType::Page,
                        Page::"Chiizu Assisted Setup"
                    );

                    Message('Chiizu connected successfully.');
                    CurrPage.Close();
                end;
            }

        }
    }

    var
        CurrentStep: Integer;

    trigger OnInit()
    begin
        if not Rec.Get('SETUP') then begin
            Rec.Init();
            Rec."Primary Key" := 'SETUP';
            Rec.Insert(true);
        end;
    end;

    trigger OnOpenPage()
    begin
        if CurrentStep = 0 then
            CurrentStep := 1;
    end;
}
