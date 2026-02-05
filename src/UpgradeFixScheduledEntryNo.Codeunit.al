codeunit 50148 "Upgrade Fix Scheduled Entry No"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Sched: Record "Chiizu Scheduled Payment";
    begin
        Sched.SetRange("Entry No.", 0);
        if Sched.FindSet() then
            Sched.DeleteAll();
    end;
}
