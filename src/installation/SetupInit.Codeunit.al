codeunit 50105 "Chiizu Setup Init"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Chiizu Setup";
    begin
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end;
    end;
}

