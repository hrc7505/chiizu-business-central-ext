codeunit 50104 "Chiizu Payment Service"
{
    // --------------------------
    // BULK PAYMENT
    // --------------------------
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]]; BankAccountNo: Code[20])
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        PayableVLE: Record "Vendor Ledger Entry";
        Batch: Record "Chiizu Payment Batch";
        UrlHelper: Codeunit "Chiizu Url Helper";
        BankAccountRec: Record "Bank Account";

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
        SetupMgmt.GetSetup(Setup);

        // 🔒 Defensive validation (execution safety)
        if not BankAccountRec.Get(BankAccountNo) then
            Error('Bank account %1 not found.', BankAccountNo);

        Clear(Payload);
        Clear(BatchesArr);

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            // 🔑 Resolve ledger entry (NOT validation)
            if not ResolvePayableVLE(InvNo, PayableVLE) then
                Error('Invoice %1 cannot be processed.', InvNo);

            PayableVLE.CalcFields("Remaining Amount");
            Amount := Abs(PayableVLE."Remaining Amount");

            BatchId := CreateBatchId();

            // ---- Create Batch (BC side) ----
            Batch.Init();
            Batch."Batch Id" := BatchId;
            Batch."Vendor No." := PayableVLE."Vendor No.";
            Batch."Total Amount" := Amount;
            Batch."Created At" := CurrentDateTime();
            Batch.Status := Batch.Status::Open;
            Batch.Insert(true);

            // Link invoice to batch
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

        // ---- Final Payload ----
        Payload.Add('callbackUrl', UrlHelper.GetPaymentWebhookUrl());
        Payload.Add('bankAccountNo', BankAccountNo);
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
    procedure ScheduleInvoicesFromFinalize(
        SelectedInvoiceNos: List of [Code[20]];
        BankAccountNo: Code[20];
        ScheduledDate: Date
    )
    var
        PayableVLE: Record "Vendor Ledger Entry";
        Scheduled: Record "Chiizu Scheduled Payment";
        InvoiceStatus: Record "Chiizu Invoice Status";
        InvNo: Code[20];
        Amount: Decimal;
        i: Integer;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices selected.');

        if ScheduledDate < Today then
            Error('Scheduled date must be today or later.');

        // Reuse your existing validations
        ValidateInvoicesForPayment(SelectedInvoiceNos);

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            if not ResolvePayableVLE(InvNo, PayableVLE) then
                Error('Invoice %1 is not payable.', InvNo);

            PayableVLE.CalcFields("Remaining Amount");
            Amount := Abs(PayableVLE."Remaining Amount");

            // 🔑 CRITICAL: never copy Entry No.
            Scheduled.Init();
            Scheduled."Invoice No." := InvNo;
            Scheduled."Vendor No." := PayableVLE."Vendor No.";
            Scheduled.Amount := Amount;
            Scheduled."Scheduled Date" := ScheduledDate;
            Scheduled.Status := Scheduled.Status::Scheduled;
            Scheduled.Insert(true); // AutoIncrement fires here

            // Optional: status bridge
            if not InvoiceStatus.Get(InvNo) then begin
                InvoiceStatus.Init();
                InvoiceStatus."Invoice No." := InvNo;
                InvoiceStatus.Insert(true);
            end;

            InvoiceStatus.Status := InvoiceStatus.Status::Scheduled;
            InvoiceStatus."Last Updated At" := CurrentDateTime();
            InvoiceStatus.Modify(true);
        end;
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

    procedure ValidateInvoicesForPayment(SelectedInvoiceNos: List of [Code[20]])
    var
        PayableVLE: Record "Vendor Ledger Entry";
        InvoiceStatus: Record "Chiizu Invoice Status";
        InvNo: Code[20];
        i: Integer;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices selected.');

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            // ❌ Block invoices already under Chiizu processing
            if InvoiceStatus.Get(InvNo) then begin
                if InvoiceStatus.Status = InvoiceStatus.Status::Processing then
                    Error(
                        'Invoice %1 is already under payment processing by Chiizu.',
                        InvNo
                    );

                if InvoiceStatus.Status = InvoiceStatus.Status::Scheduled then
                    Error(
                        'Invoice %1 is already scheduled for payment by Chiizu.',
                        InvNo
                    );
            end;

            // ✅ Ledger validation
            if not ResolvePayableVLE(InvNo, PayableVLE) then
                Error('Invoice %1 is not payable or already closed.', InvNo);

            PayableVLE.CalcFields("Remaining Amount");
            if PayableVLE."Remaining Amount" = 0 then
                Error('Invoice %1 has no remaining amount.');
        end;
    end;

    procedure BuildTempSchedulePreview(SelectedInvoiceNos: List of [Code[20]]; var TempSchedule: Record "Chiizu Scheduled Payment" temporary)
    var
        PayableVLE: Record "Vendor Ledger Entry";
        InvNo: Code[20];
        i: Integer;
    begin
        TempSchedule.Reset();
        TempSchedule.DeleteAll(); // safe – temp only

        if SelectedInvoiceNos.Count() = 0 then
            exit;

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            if not ResolvePayableVLE(InvNo, PayableVLE) then
                continue;

            PayableVLE.CalcFields("Remaining Amount");
            if PayableVLE."Remaining Amount" = 0 then
                continue;

            TempSchedule.Init();
            // 🚫 DO NOT TOUCH Entry No.
            TempSchedule."Invoice No." := InvNo;
            TempSchedule."Vendor No." := PayableVLE."Vendor No.";
            TempSchedule.Amount := Abs(PayableVLE."Remaining Amount");
            TempSchedule.Status := TempSchedule.Status::Open;
            TempSchedule.Insert(); // temp insert only
        end;
    end;

}
