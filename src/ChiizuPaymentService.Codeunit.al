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


    local procedure ExecuteBulkPayment(
    SelectedInvoiceNos: List of [Code[20]];
    BankAccountNo: Code[20];
    Endpoint: Text;
    ScheduledDate: Date
)
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
        SetupMgmt.GetSetup(Setup);

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

            // 🔹 Get or initialize invoice list
            if VendorInvoices.ContainsKey(VendorNo) then
                VendorInvoices.Get(VendorNo, InvoiceList)
            else begin
                InvoiceList := InvoiceList; // empty list
                VendorTotals.Add(VendorNo, 0);
            end;

            InvoiceList.Add(InvNo);
            VendorInvoices.Set(VendorNo, InvoiceList);

            VendorTotals.Set(
                VendorNo,
                VendorTotals.Get(VendorNo) + Amount
            );
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
}
