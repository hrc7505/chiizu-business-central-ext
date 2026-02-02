codeunit 50104 "Chiizu Payment Service"
{
    // --------------------------
    // BULK PAYMENT
    // --------------------------
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        PayableVLE: Record "Vendor Ledger Entry";
        Batch: Record "Chiizu Payment Batch";
        UrlHelper: Codeunit "Chiizu Url Helper";

        Payload: JsonObject;
        BatchesArr: JsonArray;
        BatchObj: JsonObject;
        InvoicesArr: JsonArray;
        InvoiceObj: JsonObject;

        InvNo: Code[20];
        BatchId: Code[50];
        Amount: Decimal;
        i: Integer;
        ResponseText: Text;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices selected.');

        SetupMgmt.GetSetup(Setup);

        // ✅ Initialize JSON
        Clear(Payload);
        Clear(BatchesArr);

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            if not ResolvePayableVLE(InvNo, PayableVLE) then
                Error('No payable vendor ledger entry for invoice %1.', InvNo);

            PayableVLE.CalcFields("Remaining Amount");
            Amount := Abs(PayableVLE."Remaining Amount");

            BatchId := CreateBatchId();

            // ---- Create Batch ----
            Batch.Init();
            Batch."Batch Id" := BatchId;
            Batch."Vendor No." := PayableVLE."Vendor No.";
            Batch."Total Amount" := Amount;
            Batch."Created At" := CurrentDateTime();
            Batch.Status := Batch.Status::Open;
            Batch.Insert(true);

            // 🔑 LINK invoice to batch (status still Open)
            LinkInvoiceToBatch(InvNo, BatchId);

            // ---- Invoice JSON ----
            Clear(InvoicesArr);
            Clear(InvoiceObj);

            InvoiceObj.Add('invoiceNo', InvNo);
            InvoiceObj.Add('amount', Amount);
            InvoicesArr.Add(InvoiceObj);

            // ---- Batch JSON ----
            Clear(BatchObj);
            BatchObj.Add('batchId', BatchId);
            BatchObj.Add('vendorNo', PayableVLE."Vendor No.");
            BatchObj.Add('invoices', InvoicesArr);

            BatchesArr.Add(BatchObj);
        end;

        Payload.Add('callbackUrl', UrlHelper.GetPaymentWebhookUrl());
        Payload.Add('batches', BatchesArr);
        ResponseText := CallBulkAPI(Payload, '/create-payment');
        ApplyApiResult(ResponseText);
    end;

    local procedure LinkInvoiceToBatch(InvoiceNo: Code[20]; BatchId: Code[50])
    var
        InvoiceStatus: Record "Chiizu Invoice Status";
    begin
        if not InvoiceStatus.Get(InvoiceNo) then begin
            InvoiceStatus.Init();
            InvoiceStatus."Invoice No." := InvoiceNo;
            InvoiceStatus.Insert(true);
        end;

        InvoiceStatus."Batch Id" := BatchId;
        InvoiceStatus."Last Updated At" := CurrentDateTime();
        InvoiceStatus.Modify(true);
    end;

    local procedure UpdateInvoicesProcessing(BatchId: Code[50])
    var
        Invoice: Record "Chiizu Invoice Status";
    begin
        Invoice.SetRange("Batch Id", BatchId);

        if Invoice.FindSet() then
            repeat
                Invoice.Status := Invoice.Status::Processing;
                Invoice."Last Updated At" := CurrentDateTime();
                Invoice.Modify(true);
            until Invoice.Next() = 0;
    end;


    // --------------------------
    // BULK SCHEDULING
    // --------------------------
    procedure ScheduleInvoices(var TempSchedule: Record "Chiizu Scheduled Payment" temporary): Integer
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        Payload: JsonObject;
        Schedules: JsonArray;
        Obj: JsonObject;
        ResponseText: Text;
    begin
        TempSchedule.Reset();
        if TempSchedule.IsEmpty() then
            Error('No invoices were provided.');

        SetupMgmt.GetSetup(Setup);
        Clear(Payload);
        Clear(Schedules);

        if TempSchedule.FindSet() then
            repeat
                Clear(Obj);
                Obj.Add('invoiceNo', TempSchedule."Invoice No.");
                Obj.Add('vendorNo', TempSchedule."Vendor No.");
                Obj.Add('amount', TempSchedule.Amount);
                Obj.Add(
                    'scheduledDate',
                    Format(TempSchedule."Scheduled Date", 0, '<Year4>-<Month,2>-<Day,2>')
                );

                Schedules.Add(Obj);
            until TempSchedule.Next() = 0;

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Schedules);
        Payload.Add('isScheduled', true);

        ResponseText := CallBulkAPI(Payload, '/create-scheduled-payment');
        ApplyApiResult(ResponseText);

        exit(Schedules.Count());
    end;

    // --------------------------
    // BULK CANCEL SCHEDULED PAYMENTS
    // --------------------------
    procedure CancelScheduledInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        InvoiceStatus: Record "Chiizu Invoice Status";
        Payload: JsonObject;
        Invoices: JsonArray;
        Obj: JsonObject;
        ResponseText: Text;
        InvNo: Code[20];
        i: Integer;
        EffectiveStatus: Enum "Chiizu Payment Status";
        InvalidInvoices: Text;
        HasInvalid: Boolean;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        SetupMgmt.GetSetup(Setup);
        Clear(Payload);
        Clear(Invoices);

        HasInvalid := false;
        InvalidInvoices := '';

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);
            EffectiveStatus := EffectiveStatus::Open;

            if InvoiceStatus.Get(InvNo) then
                EffectiveStatus := InvoiceStatus.Status;

            if EffectiveStatus <> EffectiveStatus::Scheduled then begin
                HasInvalid := true;
                InvalidInvoices +=
                    StrSubstNo('• %1 (status = %2)', InvNo, EffectiveStatus) + '\';
            end;
        end;

        if HasInvalid then
            Error(
                'Cancel Scheduled Payment failed.' + '\' +
                'The following invoices are not in Scheduled status:' + '\' +
                InvalidInvoices
            );

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);
            Clear(Obj);
            Obj.Add('invoiceNo', InvNo);
            Obj.Add('action', 'CANCEL');
            Invoices.Add(Obj);
        end;

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);
        Payload.Add('isCancel', true);

        ResponseText := CallBulkAPI(Payload, '/cancel-scheduled-payment');
        ApplyApiResult(ResponseText);
    end;

    // --------------------------
    // APPLY API RESULT → STATUS
    // --------------------------
    local procedure ApplyApiResult(ResponseText: Text)
    var
        Root: JsonObject;
        Token: JsonToken;
        BatchIds: JsonArray;
        BatchIdToken: JsonToken;
        Batch: Record "Chiizu Payment Batch";
        i: Integer;
    begin
        if not Root.ReadFrom(ResponseText) then
            Error('Invalid API response.');

        if not Root.Get('acceptedBatches', Token) then
            Error('acceptedBatches not found in API response.');

        BatchIds := Token.AsArray();

        for i := 0 to BatchIds.Count() - 1 do begin
            BatchIds.Get(i, BatchIdToken);

            if Batch.Get(BatchIdToken.AsValue().AsText()) then begin
                // ✅ batch → Processing
                Batch.Status := Batch.Status::Processing;
                Batch.Modify(true);

                // ✅ invoices → Processing
                UpdateInvoicesProcessing(Batch."Batch Id");
            end;
        end;
    end;

    // --------------------------
    // HELPERS
    // --------------------------
    local procedure ResolvePayableVLE(InvNo: Code[20]; var PayableVLE: Record "Vendor Ledger Entry"): Boolean
    var
        VLE: Record "Vendor Ledger Entry";
    begin
        VLE.SetRange("Document Type", VLE."Document Type"::Invoice);
        VLE.SetRange("Document No.", InvNo);
        VLE.SetRange(Open, true);

        if VLE.FindFirst() then begin
            PayableVLE := VLE;
            exit(true);
        end;
        exit(false);
    end;

    local procedure CallBulkAPI(Payload: JsonObject; Endpoint: Text): Text
    var
        ChiizuApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // -----------------------------
        // Delegate HTTP + auth to client
        // -----------------------------
        ResponseJson := ChiizuApiClient.PostJson(Endpoint, Payload);

        // -----------------------------
        // Convert JSON → Text (bulk APIs usually log/store text)
        // -----------------------------
        ResponseJson.WriteTo(ResponseText);

        exit(ResponseText);
    end;


    local procedure CreateBatchId(): Code[20]
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
    begin
        SetupMgmt.GetSetup(Setup);

        Setup."Last Batch No." += 1;
        Setup.Modify(true);

        exit(
            'BC' +
            Format(Today(), 0, '<Year4><Month,2><Day,2>') +
            '-' +
            PadStr(Format(Setup."Last Batch No."), 6, '0')
        );
    end;
}
