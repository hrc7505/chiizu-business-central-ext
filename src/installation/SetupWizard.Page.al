page 50101 "Chiizu Setup Wizard"
{
    PageType = StandardDialog;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    Caption = 'Chiizu Setup';

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
            action(Back)
            {
                Caption = 'Back';
                Enabled = CurrentStep > 1;

                trigger OnAction()
                begin
                    CurrentStep -= 1;
                end;
            }

            action(Next)
            {
                Caption = 'Next';
                Enabled = CurrentStep < 2;

                trigger OnAction()
                begin
                    if CurrentStep = 1 then
                        if Rec."API Base URL" = '' then
                            Error('API Base URL is required.');

                    CurrentStep += 1;
                end;
            }

            action(Finish)
            {
                Caption = 'Finish';
                Enabled = CurrentStep = 2;

                trigger OnAction()
                var
                    GuidedExperience: Codeunit "Guided Experience";
                begin
                    Rec."Setup Completed" := true;
                    Rec.Modify(true);

                    GuidedExperience.CompleteAssistedSetup(
                        ObjectType::Page,
                        Page::"Chiizu Setup Wizard"
                    );

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

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        if CloseAction = Action::OK then begin
            case CurrentStep of
                1:
                    begin
                        if Rec."API Base URL" = '' then
                            Error('API Base URL is required.');

                        CurrentStep := 2;
                        exit(false); // keep dialog open
                    end;

                2:
                    begin
                        Rec."Setup Completed" := true;
                        Rec.Modify(true);

                        GuidedExperience.CompleteAssistedSetup(
                            ObjectType::Page,
                            Page::"Chiizu Setup Wizard"
                        );

                        Message('Chiizu setup completed successfully.');
                    end;
            end;
        end;
    end;

}
