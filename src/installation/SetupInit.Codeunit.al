codeunit 50105 "Chiizu Setup Init"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Chiizu Setup";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        // 1️⃣ Ensure setup record exists
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end;

        // 2️⃣ Register Assisted Setup
        GuidedExperience.InsertAssistedSetup(
            'Chiizu',
            'Chiizu Setup',
            'Connect Chiizu with Business Central',
            1,
            ObjectType::Page,
            Page::"Chiizu Assisted Setup",
            Enum::"Assisted Setup Group"::Extensions,
            '',
            Enum::"Video Category"::Uncategorized,
            '',
            true
        );
    end;
}
