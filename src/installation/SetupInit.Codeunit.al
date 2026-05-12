codeunit 50105 "Chiizu Setup Init"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Chiizu Setup";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        // 1. Ensure setup record exists
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert(true);
        end;

        // 2. NEW: Automated Data Exchange Shell
        CreateJsonDataExchangeDef();

        // 3 Register Assisted Setup
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

    procedure CreateJsonDataExchangeDef()
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchLineDef: Record "Data Exch. Line Def";
        DataExchMap: Record "Data Exch. Mapping";
        ColType: Option Text,Date,Decimal,DateTime;
    begin
        // 1. HEADER
        if not DataExchDef.Get('CHIIZU') then begin
            DataExchDef.Init();
            DataExchDef.Code := 'CHIIZU';
            DataExchDef.Name := 'Chiizu API Sync';
            DataExchDef.Type := DataExchDef.Type::"Bank Statement Import";
            DataExchDef."File Type" := DataExchDef."File Type"::Json;

            // 🔹 WE LEAVE EXT DATA HANDLING BLANK. Our Interceptor handles it!
            DataExchDef."Ext. Data Handling Codeunit" := 0;

            DataExchDef.Insert();
        end else begin
            // SELF-HEALING
            if DataExchDef."Ext. Data Handling Codeunit" <> 0 then begin
                DataExchDef."Ext. Data Handling Codeunit" := 0;
                DataExchDef.Modify(true);
            end;
        end;

        // 2. LINE (Where does the array start?)
        if not DataExchLineDef.Get('CHIIZU', 'API') then begin
            DataExchLineDef.Init();
            DataExchLineDef."Data Exch. Def Code" := 'CHIIZU';
            DataExchLineDef.Code := 'API';
            DataExchLineDef."Data Line Tag" := '/transactions'; // Adjust if your root JSON array is named differently
            DataExchLineDef.Insert();
        end;

        // 3. COLUMNS (The Yodlee-style Paths)
        CreateDataExchColumn('CHIIZU', 'API', 1, 'id', '/transactions/id', ColType::Text);
        CreateDataExchColumn('CHIIZU', 'API', 2, 'date', '/transactions/date', ColType::Date);
        CreateDataExchColumn('CHIIZU', 'API', 3, 'description', '/transactions/description', ColType::Text);
        CreateDataExchColumn('CHIIZU', 'API', 4, 'amount', '/transactions/amount', ColType::Decimal);

        // 4. TABLE MAPPING
        if not DataExchMap.Get('CHIIZU', 'API', Database::"Bank Acc. Reconciliation Line") then begin
            DataExchMap.Init();
            DataExchMap."Data Exch. Def Code" := 'CHIIZU';
            DataExchMap."Data Exch. Line Def Code" := 'API';
            DataExchMap."Table ID" := Database::"Bank Acc. Reconciliation Line";
            DataExchMap."Mapping Codeunit" := Codeunit::"Process Bank Acc. Rec Lines"; // Native Microsoft Mapper
            DataExchMap.Insert();
        end;

        // 5. FIELD MAPPING
        CreateDataExchFieldMap('CHIIZU', 'API', 2, 5);  // Date -> Transaction Date
        CreateDataExchFieldMap('CHIIZU', 'API', 3, 6);  // Description -> Description
        CreateDataExchFieldMap('CHIIZU', 'API', 4, 7);  // Amount -> Statement Amount
    end;

    // --- Helper Functions ---
    local procedure CreateDataExchColumn(DefCode: Code[20]; LineCode: Code[20]; ColNo: Integer; ColName: Text[250]; JsonPath: Text[250]; DataType: Option)
    var
        DataExchCol: Record "Data Exch. Column Def";
    begin
        if not DataExchCol.Get(DefCode, LineCode, ColNo) then begin
            DataExchCol.Init();
            DataExchCol."Data Exch. Def Code" := DefCode;
            DataExchCol."Data Exch. Line Def Code" := LineCode;
            DataExchCol."Column No." := ColNo;
            DataExchCol.Name := ColName;
            DataExchCol."Data Type" := DataType;
            DataExchCol.Path := JsonPath;
            DataExchCol.Insert();
        end;
    end;

    local procedure CreateDataExchFieldMap(DefCode: Code[20]; LineCode: Code[20]; ColNo: Integer; FieldId: Integer)
    var
        DataExchField: Record "Data Exch. Field Mapping";
    begin
        if not DataExchField.Get(DefCode, LineCode, Database::"Bank Acc. Reconciliation Line", ColNo, FieldId) then begin
            DataExchField.Init();
            DataExchField."Data Exch. Def Code" := DefCode;
            DataExchField."Data Exch. Line Def Code" := LineCode;
            DataExchField."Table ID" := Database::"Bank Acc. Reconciliation Line";
            DataExchField."Column No." := ColNo;
            DataExchField."Field ID" := FieldId;
            DataExchField.Insert();
        end;
    end;
}
