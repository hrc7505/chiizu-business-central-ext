
codeunit 50106 "Chiizu Job Queue Setup"
{
    procedure EnsureScheduledPaymentJobQueue()
    var
        JQ: Record "Job Queue Entry";
        Exists: Boolean;
    begin
        // Check if a job queue entry for our processor already exists
        JQ.Reset();
        JQ.SetRange("Object Type to Run", JQ."Object Type to Run"::Codeunit);
        JQ.SetRange("Object ID to Run", 50105);
        Exists := JQ.FindFirst();

        if not Exists then begin
            JQ.Init();
            JQ."Object Type to Run" := JQ."Object Type to Run"::Codeunit;
            JQ."Object ID to Run" := 50105;
            JQ.Description := 'Chiizu Scheduled Payment Processor';
            JQ."Earliest Start Date/Time" := CreateDateTime(Today, Time());
            JQ."Recurring Job" := true;
            JQ."No. of Minutes between Runs" := 60; // run hourly; adjust as needed
            JQ.Status := JQ.Status::Ready;         // ensure it will run
            JQ.Insert(true);
        end else begin
            // Ensure it is recurring and enabled
            JQ."Recurring Job" := true;
            if JQ."No. of Minutes between Runs" = 0 then
                JQ."No. of Minutes between Runs" := 60;
            JQ.Status := JQ.Status::Ready;
            JQ.Modify(true);
        end;
    end;
}
