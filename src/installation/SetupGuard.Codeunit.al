codeunit 50103 "Chiizu Setup Guard"
{
    procedure EnsureSetupCompleted()
    var
        Setup: Record "Chiizu Setup";
    begin
        if not Setup.Get('SETUP') then
            exit;

        // Only suggest setup, do not enforce it
        if not Setup."Setup Completed" then
            Page.Run(Page::"Chiizu Assisted Setup");
    end;

}
