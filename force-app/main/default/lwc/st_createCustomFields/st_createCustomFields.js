/*************************************************************
 * @author : th.kim
 * @date : 2023-10-17
 * @group : 
 * @group-content :
 * @description : 
==============================================================
 * Ver Date Author Modification
 1.0    Initial Version
**************************************************************/ 

import { LightningElement, track } from 'lwc';
import { loadScript } from "lightning/platformResourceLoader";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jquery from '@salesforce/resourceUrl/jquery';
import sheetJs from '@salesforce/resourceUrl/sheetJs';
import createCustomFields from '@salesforce/apex/ST_CreateCustomFieldsController.createCustomFields';
import createCustomObjects from '@salesforce/apex/ST_CreateCustomFieldsController.createCustomObjects';
import getObjectNameList from '@salesforce/apex/ST_CreateCustomFieldsController.getObjectNameList';
import getProfileNameList from '@salesforce/apex/ST_CreateCustomFieldsController.getProfileNameList';
import deleteCustomFields from '@salesforce/apex/ST_CreateCustomFieldsController.deleteCustomFields';

const typeOptions = [
    { label: 'Text', value: 'Text' },
    { label: 'Picklist', value: 'Picklist' },
    { label: 'Lookup', value: 'Lookup' },
    { label: 'Number', value: 'Number' },
    { label: 'AutoNumber', value: 'AutoNumber' },
    { label: 'Date', value: 'Date' },
    { label: 'DateTime', value: 'DateTime' },
    { label: 'Time', value: 'Time' },
    { label: 'Percent', value: 'Percent' },
    { label: 'Html', value: 'Html' },
    { label: 'Email', value: 'Email' },
    { label: 'Phone', value: 'Phone' },
    { label: 'Checkbox', value: 'Checkbox' },
    { label: 'TextArea', value: 'TextArea' },
    { label: 'Currency', value: 'Currency' }/* ,
    { label: 'Text', value: 'Text' },
    { label: 'Text', value: 'Text' }, */
];

const tfOptions = [
    { label: 'false', value: false },
    { label: 'true', value: true }
];

export default class StCreateCustomFields extends LightningElement {

    acceptType = ['.xls', '.xlsx']; // 업로드 파일 형식
    searchValue;
    clickValue;
    profileValue;
    typeOptions = typeOptions;
    tfOptions = tfOptions;
    @track objNameList = [];
    @track profileList = [];
    @track profileNames = [];
    @track searchList = [];
    @track fieldList = [];
    @track returnList = [];
    progressValue = 0;
    totalCount = 0;
    successCount = 0;
    failedCount = 0;
    isProfileModal = true;
    isUpload;
    isReturn;
    isError;
    isLoading;

    /** sheet js 파일, jquery 파일 load */
    connectedCallback() {
        // window.addEventListener('keydown', this.handleKeydown.bind(this));
        getObjectNameList().then(res => {
            console.log('obj res :: ',res);
            this.objNameList = res;
        }).catch(err => {
            console.log('err :: ',err);
        });

        getProfileNameList().then(res => {
            console.log('profile res :: ',res);
            res.forEach(el => {
                this.profileList.push({label : el.Name, value : el.Name});
            });
        }).catch(err => {
            console.log('err :: ',err);
        });

        Promise.all([
            loadScript(this, jquery),
            loadScript(this, sheetJs)
        ]).then(res => {
            console.log('load !!');
        }).catch(err => {
            console.log('load err .. ',err);
            this.dispatchEvent(
                new ShowToastEvent({title: '', message: err.message, variant: 'warning'})
            );
        });
    }

    /** 파일 업로드 */
    onFileUpload(e) {
        this.isLoading = true;
        this.isReturn = false;
        this.successCount = 0;
        this.failedCount = 0;
        const file = e.target.files[0];
        const type = e.target.dataset.type;
        let reader = new FileReader();
        reader.onload = () => {
            let fileData = reader.result;
            let wb = XLSX.read(fileData, {type : 'binary'});
            let sheetName = wb.SheetNames[0];
            let workSheet = wb.Sheets[sheetName];
            let data = XLSX.utils.sheet_to_json(workSheet);
            this.fieldList = data.map(row => {
                if(row.FieldName || row.FieldLabel || row.FieldType) {
                    this.isUpload = true;
                    if(row.PickListValues) row.PickListValues = row.PickListValues.replaceAll('\r\n', ',');
                    if(row.Readable) {
                        row.Readable = true;
                    } else {
                        row.Readable = false;
                    }
                    if(row.Editable) {
                        row.Editable = true;
                    } else {
                        row.Editable = false;
                    }
                    return {
                        'apiName' : row.FieldName,
                        'label' : row.FieldLabel,
                        'type' : row.FieldType,
                        'length' : row.Length,
                        'visibleLines' : row.VisibleLines,
                        'precision' : row.NumberLength,
                        'scale' : row.DecimalPlaces,
                        'displayFormat' : row.DisplayFormat,
                        'startingNumber' : row.StartingNumber,
                        'pickListValues' : row.PickListValues,
                        'relationshipLabel' : row.RelationshipLabel,
                        'relationshipName' : row.RelationshipName,
                        'referenceTo' : row.ReferenceTo,
                        'defaultValue' : row.DefaultValue,
                        'readable' : row.Readable,
                        'editable' : row.Editable
                    }
                } else {
                    this.isUpload = false;
                }
            });
            this.totalCount = this.fieldList.length;
            console.log('fieldList :: ',JSON.stringify(this.fieldList));
            // if(type == 'obj') this.createObjects(data);
            // if(type == 'field') this.createFields(this.fieldList);
            this.isLoading = false;
        }
        reader.readAsBinaryString(file);
    }

    /** 개체 검색 onchange() */
    onSearchKeyup(e) {
        this.searchList = [];
        this.clickValue = null;
        this.searchValue = e.target.value;
        console.log('searchValue :: ',this.searchValue);
        if(this.searchValue) {
            this.searchList = this.objNameList.filter(el => el.includes(this.searchValue));
        }
        console.log('searchList :: ',JSON.stringify(searchList));
    }

    /** 검색어 클릭 onclick() */
    onSearchClick(e) {
        this.clickValue = e.target.dataset.value;
        this.searchValue = this.clickValue;
        console.log('clickValue :: ',this.clickValue);
        this.searchList = [];
    }

    /** Select Profile 버튼 */
    onProfileClick() {
        // this.isProfileModal = true;
        let temp = this.template.querySelectorAll('.modal');
        temp.forEach(el => {
            el.style.display = 'block';
            console.log('temp :: ',el);
        })
    }

    /** Profile Checkbox 선택 */
    onProfileChkClick(e) {
        if(e.target.checked) this.profileNames.push(e.target.dataset.name);
        else this.profileNames = this.profileNames.filter(el => el != e.target.dataset.name);
        console.log('profileNames :: ',JSON.stringify(this.profileNames));
    }

    /** 프로필 모달 창 닫기 버튼 */
    onCloseModalClick() {
        // this.isProfileModal = false;
        let temp = this.template.querySelectorAll('.modal');
        temp.forEach(el => {
            el.style.display = 'none';
            console.log('temp :: ',el);
        })
    }

    handleProfileChange(e) {
        
    }

    /** Upload 버튼 */
    onUploadClick() {
        if(!this.clickValue) {
            this.dispatchEvent(
                new ShowToastEvent({title: '', message: '개체를 선택해주세요 ~~', variant: 'warning'})
            );
        } else {
            this.createFields(this.fieldList);
        }
    }

    /** Retry Failed 버튼 */
    onRetryFailedClick() {
        const retryList = [];
        this.isError = false;
        this.returnList.forEach(el => {
            if(el.error) {
                retryList.push(el.field);
            }
        });
        console.log('retryList :: ',JSON.stringify(retryList));
        this.createFields(retryList);
    }

    handleTextChange(e) {
        this.changeData(e.target.dataset.col, e.target.dataset.row, e.target.value);
    }

    handleNumberChange(e) {
        e.target.value = e.target.value.replace(/[^0-9]/g, "");
        this.changeData(e.target.dataset.col, e.target.dataset.row, e.target.value);
    }

    onComboboxChange(e) {
        this.changeData(e.target.dataset.col, e.target.dataset.row, e.target.value);
    }

    changeData(col, row, data) {
        console.log('col :: ',col, '', typeof(col));
        console.log('row :: ',row), '', typeof(col);
        console.log('data :: ',data, '', typeof(col));
        switch(col) {
            case 'apiName' :
                this.fieldList[row].apiName = data;
                break;
            case 'label' :
                this.fieldList[row].label = data;
                break;
            case 'type' :
                this.fieldList[row].type = data;
                break;
            case 'length' :
                this.fieldList[row].length = data;
                break;
            case 'visibleLines' :
                this.fieldList[row].visibleLines = data;
                break;
            case 'precision' :
                this.fieldList[row].precision = data;
                break;
            case 'scale' :
                this.fieldList[row].scale = data;
                break;
            case 'displayFormat' :
                this.fieldList[row].displayFormat = data;
                break;
            case 'startingNumber' :
                this.fieldList[row].startingNumber = data;
                break;
            case 'pickListValues' :
                this.fieldList[row].pickListValues = data;
                break;
            case 'relationshipLabel' :
                this.fieldList[row].relationshipLabel = data;
                break;
            case 'relationshipName' :
                this.fieldList[row].relationshipName = data;
                break;
            case 'referenceTo' :
                this.fieldList[row].referenceTo = data;
                break;
            case 'defaultValue' :
                this.fieldList[row].defaultValue = data;
                break;
            case 'readable' :
                this.fieldList[row].readable = JSON.parse(data.toLowerCase());
                break;
            case 'editable' :
                this.fieldList[row].editable = JSON.parse(data.toLowerCase());
                break;
        }
    }

    /** 개체 생성 함수 */
    createObjects(data) {
        let excelData = [];
        let batchSize = 10; // 컨트롤러로 넘길 데이터 사이즈
        let forSize = Math.ceil(data.length/batchSize); // 반복할 사이즈
        try {
            for(let i = 0; i < forSize; i++) {
                excelData = data.slice((i)*batchSize, (i+1)*batchSize).map(row => {
                    let pickListValues;
                    if(row.pickListValues) pickListValues = row.pickListValues.split('\r\n');
                    return {
                        'apiName' : row.apiName,
                        'label' : row.label,
                        'nameType' : row.nameType, 
                        'nameLabel' : row.nameLabel,
                    }
                });
                console.log('excelData :: ',JSON.stringify(excelData));
                createCustomObjects({
                    data : JSON.stringify(excelData)
                }).then(res => {
                    console.log('res :: ',res);
                    this.dispatchEvent(
                        new ShowToastEvent({title: '', message: 'Upload Success !', variant: 'success'})
                    );
                }).catch(err => {
                    console.log('err :: ',err);
                    this.dispatchEvent(
                        new ShowToastEvent({title: '', message: err.body.message, variant: 'warning'})
                    );
                });
            }
        } catch(err) {
            console.log('err :: ',JSON.stringify(err));
        }
    }

    /** 필드 생성 함수 */
    async createFields(data) {
        this.isLoading = true;
        this.isReturn = true;
        this.progressValue = 0;
        this.successCount = 0;
        this.failedCount = 0;
        this.totalCount = data.length;
        console.log('profileNames :: ',JSON.stringify(this.profileNames));
        this.returnList = [];
        let fieldData = [];
        const batchSize = 10; // 컨트롤러로 잘라서 넘길 데이터 사이즈
        let forSize = Math.ceil(data.length/batchSize); // 반복할 사이즈
        let progress = Math.ceil(100/forSize); // 프로세스가 한번 완료될 때의 퍼센트 값
        for(let i = 0; i < forSize; i++) {
            fieldData = data.slice((i)*batchSize, (i+1)*batchSize).map(row => {
                console.log('row :: ',JSON.stringify(row));
                if(row.pickListValues != null && typeof row.pickListValues == 'string') row.pickListValues = row.pickListValues.split(',');
                // if(row.precision != null) row.precision = Number(row.precision);
                // if(row.scale != null) row.scale = Number(row.scale);
                // if(row.startingNumber != null) row.startingNumber = Number(row.startingNumber);
                // if(row.visibleLines != null) row.visibleLines = Number(row.visibleLines);
                return row;
                // return {
                //     'apiName' : row.apiName,
                //     'label' : row.label,
                //     'type' : row.type,
                //     'length' : row.length,
                //     'visibleLines' : row.visibleLines,
                //     'precision' : row.precision,
                //     'scale' : row.scale,
                //     'displayFormat' : row.displayFormat,
                //     'startingNumber' : row.startingNumber,
                //     'pickListValues' : row.pickListValues,
                //     'relationshipLabel' : row.relationshipLabel,
                //     'relationshipName' : row.relationshipName,
                //     'referenceTo' : row.referenceTo,
                //     'defaultValue' : row.defaultValue,
                //     'readable' : row.readable,
                //     'editable' : row.editable
                // }
            });
            console.log('fieldData :: ',JSON.stringify(fieldData));
            await createCustomFields({
                objName : this.clickValue,
                data : JSON.stringify(fieldData),
                profileNames : this.profileNames
            }).then(res => {
                console.log('res :: ',res);
                const returnData = JSON.parse(res);
                returnData.forEach(data => {
                    if(data.error) this.failedCount++;
                    else if(data.success) this.successCount++;
                    this.returnList.push(data);
                });
            }).catch(err => {
                console.log('err :: ',err);
                this.dispatchEvent(
                    new ShowToastEvent({title: '', message: err.body.message, variant: 'warning'})
                );
            });
            this.isLoading = false;
            this.returnList.forEach(el => {
                if(el.type == 'field') el.isField = true;
                else if(el.type == 'profile') el.isProfile = true;
                if(el.error) this.isError = true;
            });
            if(this.progressValue < 100) this.progressValue += progress;
            else this.progressValue = 100;
            this.isLoading = true;
        }
        this.totalCount = this.returnList.length;
        this.isLoading = false;
    }

    /** 파일 업로드 중 새로고침 막는 onkeydown() 함수 */
    // handleKeydown(e){
    //     if(this.isLoading == true){
    //         e.preventDefault();
    //         alert("파일 업로드 중입니다. \n현재 페이지를 유지해주세요.");
    //     }
    // }
}