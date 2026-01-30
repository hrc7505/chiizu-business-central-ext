codeunit 50102 "Chiizu Guided Setup"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        RegisterSetup();
    end;

    local procedure RegisterSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        GuidedExperience.InsertAssistedSetup(
            'Chiizu Setup',
            'Chiizu Setup',
            'Initial setup for Chiizu extension',
            10,
            ObjectType::Page,
            Page::"Chiizu Setup Wizard",
            "Assisted Setup Group"::Extensions,
            '',
            "Video Category"::GettingStarted,
            ''
        );
    end;
}
