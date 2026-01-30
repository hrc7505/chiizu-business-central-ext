codeunit 50103 "Chiizu Setup Guard"
{
    procedure EnsureSetupCompleted()
    var
        Setup: Record "Chiizu Setup";
    begin
        if not Setup.Get('SETUP') then
            Error('Chiizu setup is not initialized.');

        if not Setup."Setup Completed" then begin
            Page.RunModal(Page::"Chiizu Setup Wizard");
            // Error('Please complete Chiizu setup first.');
        end;
    end;
}
