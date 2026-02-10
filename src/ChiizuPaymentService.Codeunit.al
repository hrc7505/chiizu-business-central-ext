codeunit 50104 "Chiizu Payment Service"
{
    // --------------------------
    // BULK INVOICE PAYMENT
    // --------------------------
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]]; BankAccountNo: Code[20])
    begin
        ExecuteBulkPayment(SelectedInvoiceNos, BankAccountNo, '/create-payment', 0D);
    end;

    // --------------------------
    // SCHEDULE PAYMENT
    // --------------------------
    procedure ScheduleInvoicesFromFinalize(SelectedInvoiceNos: List of [Code[20]]; BankAccountNo: Code[20]; ScheduledDate: Date)
    begin
        if ScheduledDate < Today then
            Error('Scheduled date must be today or later.');

        ExecuteBulkPayment(SelectedInvoiceNos, BankAccountNo, '/schedule-payment', ScheduledDate);
    end;


    local procedure ExecuteBulkPayment(SelectedInvoiceNos: List of [Code[20]]; BankAccountNo: Code[20]; Endpoint: Text; ScheduledDate: Date)
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        PayableVLE: Record "Vendor Ledger Entry";
        Batch: Record "Chiizu Payment Batch";
        BankAccountRec: Record "Bank Account";
        UrlHelper: Codeunit "Chiizu Url Helper";

        // 🔹 Vendor grouping
        VendorInvoices: Dictionary of [Code[20], List of [Code[20]]];
        VendorTotals: Dictionary of [Code[20], Decimal];

        InvoiceList: List of [Code[20]];
        VendorNo: Code[20];

        Payload: JsonObject;
        BatchesArr: JsonArray;
        BatchObj: JsonObject;
        InvoicesArr: JsonArray;
        InvoiceObj: JsonObject;

        InvNo: Code[20];
        BatchId: Code[50];
        Amount: Decimal;
        TotalAmount: Decimal;
        i: Integer;
        ResponseText: Text;
    begin
        // --------------------------
        // 1️⃣ Setup & validation
        // --------------------------
        Setup := SetupMgmt.EnsureConnected();

        if not BankAccountRec.Get(BankAccountNo) then
            Error('Bank account %1 not found.', BankAccountNo);

        ValidateInvoicesForPayment(SelectedInvoiceNos);

        Clear(VendorInvoices);
        Clear(VendorTotals);

        // --------------------------
        // 2️⃣ GROUP invoices by vendor
        // --------------------------
        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            if not ResolvePayableVLE(InvNo, PayableVLE) then
                Error('Invoice %1 cannot be processed.', InvNo);

            VendorNo := PayableVLE."Vendor No.";
            PayableVLE.CalcFields("Remaining Amount");
            Amount := Abs(PayableVLE."Remaining Amount");

            if VendorInvoices.ContainsKey(VendorNo) then
                VendorInvoices.Get(VendorNo, InvoiceList)
            else begin
                // 🔹 FIX: Properly clear the list for each new vendor
                Clear(InvoiceList);
                VendorTotals.Add(VendorNo, 0);
            end;

            if not InvoiceList.Contains(InvNo) then begin
                InvoiceList.Add(InvNo);
                VendorInvoices.Set(VendorNo, InvoiceList);

                VendorTotals.Set(VendorNo, VendorTotals.Get(VendorNo) + Amount);
            end;
        end;

        // --------------------------
        // 3️⃣ Build BC batches + JSON
        // --------------------------
        Clear(Payload);
        Clear(BatchesArr);

        foreach VendorNo in VendorInvoices.Keys() do begin
            VendorInvoices.Get(VendorNo, InvoiceList);
            TotalAmount := VendorTotals.Get(VendorNo);

            BatchId := CreateBatchId();

            // 🔹 BC batch (ONE per vendor)
            Batch.Init();
            Batch."Batch Id" := BatchId;
            Batch."Vendor No." := VendorNo;
            Batch."Total Amount" := TotalAmount;
            Batch."Created At" := CurrentDateTime();
            Batch.Status := Batch.Status::Open;
            Batch.Insert(true);

            // 🔹 JSON invoices
            Clear(InvoicesArr);

            for i := 1 to InvoiceList.Count() do begin
                InvNo := InvoiceList.Get(i);

                ResolvePayableVLE(InvNo, PayableVLE);
                PayableVLE.CalcFields("Remaining Amount");
                Amount := Abs(PayableVLE."Remaining Amount");

                Clear(InvoiceObj);
                InvoiceObj.Add('invoiceNo', InvNo);
                InvoiceObj.Add('amount', Amount);
                InvoicesArr.Add(InvoiceObj);

                // 🔗 Link invoice → batch
                LinkInvoiceToBatch(InvNo, BatchId);
            end;

            // 🔹 JSON batch
            Clear(BatchObj);
            BatchObj.Add('batchId', BatchId);
            BatchObj.Add('vendorNo', VendorNo);
            BatchObj.Add('invoices', InvoicesArr);

            BatchesArr.Add(BatchObj);
        end;

        // --------------------------
        // 4️⃣ Final payload
        // --------------------------
        Payload.Add('callbackUrl', UrlHelper.GetPaymentWebhookUrl());
        Payload.Add('bankAccountNo', BankAccountNo);
        Payload.Add('batches', BatchesArr);

        // ⭐ Scheduled date at TOP LEVEL
        if ScheduledDate <> 0D then
            Payload.Add('scheduledDate', Format(ScheduledDate));

        // --------------------------
        // 5️⃣ Call API + apply result
        // --------------------------
        ResponseText := CallBulkAPI(Payload, Endpoint);
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
    // BULK CANCEL SCHEDULED PAYMENTS
    // --------------------------
    // --------------------------
    // CANCEL SCHEDULED PAYMENT (SINGLE)
    // --------------------------
    procedure CancelScheduledInvoice(InvoiceNo: Code[20])
    var
        InvoiceStatus: Record "Chiizu Invoice Status";
        Batch: Record "Chiizu Payment Batch";
        Payload: JsonObject;
        ResponseText: Text;
        BatchId: Code[50];
    begin
        // 1. Validation: Must be Scheduled
        if not InvoiceStatus.Get(InvoiceNo) then
            Error('Invoice %1 status not found.', InvoiceNo);

        if InvoiceStatus.Status <> InvoiceStatus.Status::Scheduled then
            Error('Only scheduled invoices can be cancelled.');

        BatchId := InvoiceStatus."Batch Id";
        if BatchId = '' then
            Error('Invoice %1 is not associated with a batch.', InvoiceNo);

        // 2. Build Payload { "batchId": "...", "invoiceId": "..." }
        Payload.Add('batchId', BatchId);
        Payload.Add('invoiceId', InvoiceNo);

        // 3. Call API
        // Expected response: { "isCancelled": true, "batchId": "...", "invoiceNo": "..." }
        ResponseText := CallBulkAPI(Payload, '/cancel-scheduled-payment');

        // 4. Handle Result & Local Cleanup
        HandleCancelResponse(ResponseText, InvoiceNo, BatchId);
    end;

    local procedure HandleCancelResponse(ResponseText: Text; InvoiceNo: Code[20]; BatchId: Code[50])
    var
        ResultObj: JsonObject;
        IsCancelledToken: JsonToken;
        InvoiceStatus: Record "Chiizu Invoice Status";
        Batch: Record "Chiizu Payment Batch";
    begin
        if not ResultObj.ReadFrom(ResponseText) then
            Error('Invalid response from cancellation API.');

        if ResultObj.Get('isCancelled', IsCancelledToken) then
            if IsCancelledToken.AsValue().AsBoolean() then begin

                // 5. Remove link/Reset status to Open
                if InvoiceStatus.Get(InvoiceNo) then begin
                    InvoiceStatus."Batch Id" := '';
                    InvoiceStatus."Scheduled Date" := 0D;
                    InvoiceStatus.Status := InvoiceStatus.Status::Open;
                    InvoiceStatus."Last Updated At" := CurrentDateTime();
                    InvoiceStatus.Modify(true);
                end;

                // 6. If batch has no more invoices, delete the batch
                InvoiceStatus.Reset();
                InvoiceStatus.SetRange("Batch Id", BatchId);

                if InvoiceStatus.IsEmpty() then begin
                    if Batch.Get(BatchId) then
                        Batch.Delete(true);
                end;

                Message('Payment for invoice %1 cancelled successfully.', InvoiceNo);
            end;
    end;

    // --------------------------
    // APPLY API RESULT → STATUS
    // --------------------------
    local procedure ApplyApiResult(ResponseText: Text)
    var
        Root: JsonObject;
        StatusToken: JsonToken;
        Token: JsonToken;
        BatchIds: JsonArray;
        BatchIdToken: JsonToken;

        Batch: Record "Chiizu Payment Batch";
        InvoiceStatus: Record "Chiizu Invoice Status";

        ScheduledDateToken: JsonToken;
        ScheduledDateTxt: Text;
        ScheduledDate: Date;

        ApiStatusTxt: Text;
        ApiStatus: Enum "Chiizu Payment Status";
        i: Integer;
    begin
        // ----------------------------
        // Parse API response
        // ----------------------------
        if not Root.ReadFrom(ResponseText) then
            Error('Invalid API response.');

        // ----------------------------
        // 1️⃣ Read status
        // ----------------------------
        if not Root.Get('status', StatusToken) then
            Error('status not found in API response.');

        ApiStatusTxt := UpperCase(StatusToken.AsValue().AsText());

        case ApiStatusTxt of
            'PROCESSING':
                ApiStatus := ApiStatus::Processing;
            'SCHEDULED':
                ApiStatus := ApiStatus::Scheduled;
            else
                Error('Unsupported status returned by API: %1', ApiStatusTxt);
        end;

        // ----------------------------
        // 2️⃣ Read accepted batches
        // ----------------------------
        if not Root.Get('acceptedBatches', Token) then
            Error('acceptedBatches not found in API response.');

        BatchIds := Token.AsArray();

        // ----------------------------
        // 3️⃣ Read scheduled date (optional)
        // ----------------------------
        Clear(ScheduledDate);
        if Root.Get('scheduledDate', ScheduledDateToken) then begin
            ScheduledDateTxt := ScheduledDateToken.AsValue().AsText();

            // API likely returns ISO date-time → extract YYYY-MM-DD
            if not Evaluate(ScheduledDate, CopyStr(ScheduledDateTxt, 1, 10)) then
                Error('Invalid scheduledDate format: %1', ScheduledDateTxt);
        end;

        // ----------------------------
        // 4️⃣ Apply updates consistently
        // ----------------------------
        for i := 0 to BatchIds.Count() - 1 do begin
            BatchIds.Get(i, BatchIdToken);

            if not Batch.Get(BatchIdToken.AsValue().AsText()) then
                continue;

            // 🔹 Update batch status
            Batch.Status := ApiStatus;
            Batch.Modify(true);

            // 🔹 Update invoices under this batch
            InvoiceStatus.Reset();
            InvoiceStatus.SetRange("Batch Id", Batch."Batch Id");

            if InvoiceStatus.FindSet(true) then
                repeat
                    // ✔ System-safe status + scheduled date update
                    InvoiceStatus.SetStatusSystem(ApiStatus, (ApiStatus = ApiStatus::Scheduled) ? ScheduledDate : 0D);

                    // ✔ Audit
                    InvoiceStatus."Last Updated At" := CurrentDateTime();
                    InvoiceStatus.Modify(true);

                until InvoiceStatus.Next() = 0;
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
        Batch: Record "Chiizu Payment Batch";
        NewBatchId: Code[20];
    begin
        Setup.LockTable(); // 🔹 Prevent concurrency issues

        // 🔹 Use your new logic: Validate and get the record in one go
        Setup := SetupMgmt.EnsureConnected();

        Setup."Last Batch No." += 1;
        Setup.Modify(true);

        // 🔹 Reserve the number immediately so others don't grab it
        Commit();

        NewBatchId := 'BC' + Format(Today(), 0, '<Year4><Month,2><Day,2>') + '-' +
                      PadStr(Format(Setup."Last Batch No."), 6, '0');

        // 🛑 DUPLICATE GUARD: If the ID exists, throw a clear error instead of a system crash
        if Batch.Get(NewBatchId) then
            Error('Batch ID %1 already exists. Please manually increase "Last Batch No." in Chiizu Setup.', NewBatchId);

        exit(NewBatchId);
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
}
