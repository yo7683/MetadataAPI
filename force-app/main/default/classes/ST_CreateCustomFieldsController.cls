/*************************************************************
 * @author : th.kim
 * @date : 2023-10-17
 * @group :
 * @group-content :
 * @description :
==============================================================
 * Ver          Date             Author         Modification
   1.0          2023-10-17       th.kim         Initial Version
**************************************************************/

public with sharing class ST_CreateCustomFieldsController {

    public class ObjectData {
        public String apiName;              // 개체 api명
        public String label;                // 개체 라벨
        public String nameType;             // 개체 이름 타입
        public String nameLabel;            // 개체 이름 라벨
    }

    public class FieldData {
        public String apiName;              // 필드 api명
        public String label;                // 필드 라벨
        public String type;                 // 필드 타입
        public String defaultValue;         // 기본 값
        public Integer length;              // (Text/LongTextArea) 텍스트 길이
        public Integer visibleLines;        // (LongTextArea) 볼 수 있는 줄
        public Integer precision;           // (Number) 전체 숫자 길이
        public Integer scale;               // (Number) 소수 자릿수
        public String displayFormat;        // (AutoNumber) 표시 형식
        public Integer startingNumber;      // (AutoNumber) 시작 숫자
        public List<String> pickListValues; // (PickList) 선택목록 데이터
        public String relationshipLabel;    // (Lookup) 관련 목록 라벨
        public String relationshipName;     // (Lookup) 하위 관계 이름
        public String referenceTo;          // (Lookup) 조회할 개체 api명
        // public String formula;
        public Boolean readable;            // 프로필 읽기 권한
        public Boolean editable;            // 프로필 편집 권한
    }

    public class SaveResult {
        public Boolean error;
        public Boolean success;
        public String fullName;
        public String type;
        public String status;
        public String message;
        public FieldData field;
    }

    // 개체 API명 뽑아오는 메서드
    @AuraEnabled
    public static List<String> getObjectNameList() {
        List<String> objectNameList = new List<String>();

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (String objectName : globalDescribe.keySet()) {
            objectNameList.add(objectName);
        }

        return objectNameList;
    }

    @AuraEnabled
    public static List<Profile> getProfileNameList() {
        return [SELECT Id, Name FROM Profile WHERE UserType = 'Standard'];
    }

    // 메타 데이터 API 커스텀 개체 생성 메서드
    @AuraEnabled
    public static void createCustomObjects(String data) {
        List<ObjectData> objDataList = (List<ObjectData>) JSON.deserialize(data, List<ObjectData>.class);

        List<MetadataService.Metadata> metadataList = new List<MetadataService.Metadata>();
        for(ObjectData objData : objDataList) {
            MetadataService.CustomObject customObject = new MetadataService.CustomObject();
            customObject.fullName = objData.apiName;
            customObject.label = objData.label;
            customObject.pluralLabel = objData.label;
            customObject.nameField = new MetadataService.CustomField();
            customObject.nameField.type_x = objData.nameType;
            customObject.nameField.label = objData.nameLabel;
            customObject.deploymentStatus = 'Deployed';
            customObject.sharingModel = 'ReadWrite';
            metadataList.add(customObject);
        }

        MetadataService.MetadataPort objectService = metadataService();
        List<MetadataService.SaveResult> results = objectService.createMetadata(metadataList);
        System.debug(results);
        for(MetadataService.SaveResult result : results) {
            if(results[0].errors != null) {
                System.debug('object err :: ' + result.errors);
                CalloutException e = new CalloutException();
                e.setMessage('object err :: ' + result.errors[0].message);
                throw e;
            }
        }
    }

    /**
     * @description : 메타 데이터 API 커스텀 필드 생성 메서드
     * @param objName : 개체 API명
     * @param data : 사용자 정의 필드 데이터 리스트
     * @param profileNames : field-level-security 설정할 프로필 Name 리스트
     *
     * @return JSON 타입 Save 결과
     */
    @AuraEnabled
//    @Future
    public static String createCustomFields(String objName, String data, List<String> profileNames) {
        try {
            List<FieldData> fieldDataList = (List<FieldData>) JSON.deserialize(data, List<FieldData>.class);
            List<SaveResult> saveResultList = new List<SaveResult>();
            List<SaveResult> fieldResultList = createFieldMetadataService(objName, fieldDataList);
            for(SaveResult saveResult : fieldResultList) {
                saveResultList.add(saveResult);
            }
            /*List<SaveResult> profileResultList = */upsertProfileMetadataService(objName, profileNames, data);
            /*for(SaveResult saveResult : profileResultList) {
                saveResultList.add(saveResult);
            }*/
            return JSON.serialize(saveResultList);
//
//            List<MetadataService.CustomField> customFieldList = new List<MetadataService.CustomField>();
//            List<MetadataService.ProfileFieldLevelSecurity> fieldSecList = new List<MetadataService.ProfileFieldLevelSecurity>();
//            Map<String, FieldData> fieldNameMap = new Map<String, FieldData>();
//            for(FieldData field : fieldDataList) {
//                System.debug('field :: ' + field);
//                MetadataService.CustomField customField = new MetadataService.CustomField();
//                customField.fullName = objName + '.' + field.apiName;
//                customField.label = field.label;
//                customField.type_x = field.type;
//
//                if(field.type == 'Picklist') {
//                    List<MetadataService.StandardValue> values = new List<MetadataService.StandardValue>();
//                    for(String str : field.pickListValues) {
//                        MetadataService.StandardValue customValue = new MetadataService.StandardValue();
//                        customValue.fullName = str;
//                        customValue.default_x = false;
//                        customValue.description = '';
//                        customValue.isActive = true;
//                        customValue.label = str;
//                        values.add(customValue);
//                    }
//
//                    MetadataService.ValueSet picklistValueSet = new MetadataService.ValueSet();
//                    MetadataService.ValueSetValuesDefinition valueDefinition = new MetadataService.ValueSetValuesDefinition();
//                    valueDefinition.value = values;
//                    valueDefinition.sorted = false;
//                    picklistValueSet.valueSetDefinition = valueDefinition;
//
//                    customField.valueSet = picklistValueSet;
//                } else if(field.type == 'Lookup') {
//                    customField.relationshipLabel = field.relationshipLabel;
//                    customField.relationshipName = field.relationshipName;
//                    customField.referenceTo = field.referenceTo;
//                } else if(field.type == 'Text'){
//                    customField.length = field.length;
//                } else if (field.type == 'LongTextArea') {
//                    customField.length = field.length;
//                    customField.visibleLines = field.visibleLines;
//                } else if (field.type == 'Number') {
//                    customField.precision = field.precision;
//                    customField.scale = field.scale;
//                } else if (field.type == 'formula') {
//                    // customField.formula = 'TEXT(Another_Field__c) + " is great!"'; // 공식 표현식
//                }
//                customFieldList.add(customField);
//
//                // Set field-level-security
//                MetadataService.ProfileFieldLevelSecurity fieldSec = new MetadataService.ProfileFieldLevelSecurity();
//                fieldSec.field = objName + '.' + field.apiName;
//                if (field.readable != null) {
//                    fieldSec.readable = field.readable;
//                } else {
//                    fieldSec.readable = false;
//                }
//                if (field.editable != null) {
//                    if (field.editable) {
//                        fieldSec.editable = true;
//                        fieldSec.readable = true;
//                    } else {
//                        fieldSec.editable = false;
//                    }
//                } else {
//                    fieldSec.editable = false;
//                }
//                fieldSecList.add(fieldSec);
//                fieldNameMap.put(customField.fullName, field);
//            }
//            System.debug('customFieldList :: ' + customFieldList);
//            System.debug('fieldSecList :: ' + fieldSecList);
//
//            // Create Custom Fields
//            MetadataService.MetadataPort fieldService = metadataService();
//            List<MetadataService.SaveResult> results = fieldService.createMetadata(customFieldList);
//
//            List<SaveResult> saveResultList = new List<SaveResult>();
//            for(MetadataService.SaveResult result : results) {
//                System.debug('field result :: ' + result);
//                SaveResult saveResult = new SaveResult();
//                saveResult.field = fieldNameMap.get(result.fullName);
//                saveResult.type = 'field';
//                saveResult.fullName = result.fullName;
//                if(result.errors != null) {
//                    System.debug('field result :: ' + result.errors);
//                    saveResult.error = true;
//                    saveResult.success = false;
//                    saveResult.status = 'error';
//                    saveResult.message = result.errors[0].message;
//                } else {
//                    saveResult.error = false;
//                    saveResult.success = true;
//                    saveResult.status = 'success';
//                    saveResult.message = 'success';
//                }
//                saveResultList.add(saveResult);
//            }
//            System.debug('saveResultList :: ' + saveResultList);

            // Upsert Profile field-level-security
           /* MetadataService.MetadataPort profileService = metadataService();
            List<MetadataService.ProfileTabVisibility> tvs = new List<MetadataService.ProfileTabVisibility>();
            for(String profileName : profileNames) {
                String fullName = queryToolingApi(profileName);
                MetadataService.Profile profile = (MetadataService.Profile) profileService.readMetadata('Profile',new List<String>{fullName}).getRecords()[0];
                profile.tabVisibilities = tvs;
                profile.fieldPermissions = fieldSecList;
                List<MetadataService.UpsertResult> upsertResults = profileService.upsertMetadata(new List<MetadataService.Metadata>{profile});
                System.debug(upsertResults);
                for(MetadataService.UpsertResult result : upsertResults) {
                    System.debug('profile result :: ' + result);
                    SaveResult saveResultObj = new SaveResult();
                    saveResultObj.type = 'profile';
                    saveResultObj.fullName = result.fullName;
                    if(result.errors != null) {
                        System.debug('profile err :: ' + result.errors);
                        saveResultObj.error = true;
                        saveResultObj.success = false;
                        saveResultObj.status = 'error';
                        saveResultObj.message = result.errors[0].message;
                    } else {
                        saveResultObj.error = false;
                        saveResultObj.success = true;
                        saveResultObj.status = 'success';
                        saveResultObj.message = 'success';
                    }
                    saveResultList.add(saveResultObj);
                }
            }*/
        } catch (Exception e) {
            System.debug('err :: ' + e.getMessage() + ' || ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description : 사용자 정의 필드 생성 서비스 메서드
     * @param objName : 개체 API명
     * @param fieldDataList : 생성할 필드 데이터 리스트
     *
     * @return : 필드 생성 결과 리스트
     */
    private static List<SaveResult> createFieldMetadataService(String objName, List<FieldData> fieldDataList) {
        List<MetadataService.CustomField> customFieldList = new List<MetadataService.CustomField>();
        Map<String, FieldData> fieldNameMap = new Map<String, FieldData>();
        for(FieldData field : fieldDataList) {
            System.debug('field :: ' + field);
            MetadataService.CustomField customField = new MetadataService.CustomField();
            customField.fullName = objName + '.' + field.apiName;
            customField.label = field.label;
            customField.type_x = field.type;
            if(String.isNotBlank(field.defaultValue)) customField.defaultValue = field.defaultValue;

            if(field.type == 'Picklist') {
                List<MetadataService.StandardValue> values = new List<MetadataService.StandardValue>();
                for(String str : field.pickListValues) {
                    MetadataService.StandardValue customValue = new MetadataService.StandardValue();
                    customValue.fullName = str;
                    customValue.default_x = false;
                    customValue.description = '';
                    customValue.isActive = true;
                    customValue.label = str;
                    values.add(customValue);
                }

                MetadataService.ValueSet picklistValueSet = new MetadataService.ValueSet();
                MetadataService.ValueSetValuesDefinition valueDefinition = new MetadataService.ValueSetValuesDefinition();
                valueDefinition.value = values;
                valueDefinition.sorted = false;
                picklistValueSet.valueSetDefinition = valueDefinition;

                customField.valueSet = picklistValueSet;
            } else if(field.type == 'Lookup') {
                customField.relationshipLabel = field.relationshipLabel;
                customField.relationshipName = field.relationshipName;
                customField.referenceTo = field.referenceTo;
            } else if (field.type == 'Url') {
                customField.length = 255;
            } else if(field.type == 'Text'){
                customField.length = field.length;
            } else if (field.type == 'LongTextArea' || field.type == 'Html') {
                customField.length = field.length;
                customField.visibleLines = field.visibleLines;
            } else if (field.type == 'Number' || field.type == 'Percent' || field.type == 'Currency') {
                customField.precision = field.precision;
                customField.scale = field.scale;
            } else if (field.type == 'formula') {
                // customField.formula = 'TEXT(Another_Field__c) + " is great!"'; // 공식 표현식
            }
            customFieldList.add(customField);
            fieldNameMap.put(customField.fullName, field);
        }
        System.debug('customFieldList :: ' + customFieldList);

        // Create Custom Fields
        MetadataService.MetadataPort fieldService = metadataService();
        List<MetadataService.SaveResult> results = fieldService.createMetadata(customFieldList);
        List<SaveResult> saveResultList = new List<SaveResult>();
        for(MetadataService.SaveResult result : results) {
            System.debug('field result :: ' + result);
            SaveResult saveResult = new SaveResult();
            saveResult.field = fieldNameMap.get(result.fullName);
            saveResult.type = 'field';
            saveResult.fullName = result.fullName;
            if(result.errors != null) {
                System.debug('field result :: ' + result.errors);
                saveResult.error = true;
                saveResult.success = false;
                saveResult.status = 'error';
                saveResult.message = result.errors[0].message;
            } else {
                saveResult.error = false;
                saveResult.success = true;
                saveResult.status = 'success';
                saveResult.message = 'success';
            }
            saveResultList.add(saveResult);
        }
        System.debug('saveResultList :: ' + saveResultList);
        return saveResultList;
    }

    /**
     * @description : 사용자 정의 필드 field-level-security 프로필 Upsert 서비스 메서드
     * @param objName : 개체 Api명
     * @param profileNames : Upsert할 프로필 Name 리스트
     * @param data : JSON 형식 필드 데이터
     */
    @Future(Callout=true)
    private static void /*List<SaveResult>*/ upsertProfileMetadataService(String objName, List<String> profileNames, String data/*, List<FieldData> fieldDataList*/) {
        List<FieldData> fieldDataList = (List<FieldData>) JSON.deserialize(data, List<FieldData>.class);
        // Set field-level-security
        List<MetadataService.ProfileFieldLevelSecurity> fieldSecList = new List<MetadataService.ProfileFieldLevelSecurity>();
        for(FieldData field : fieldDataList) {
            MetadataService.ProfileFieldLevelSecurity fieldSec = new MetadataService.ProfileFieldLevelSecurity();
            fieldSec.field = objName + '.' + field.apiName;
            if (field.readable != null) {
                fieldSec.readable = field.readable;
            } else {
                fieldSec.readable = false;
            }
            if (field.editable != null) {
                if (field.editable) {
                    fieldSec.editable = true;
                    fieldSec.readable = true;
                } else {
                    fieldSec.editable = false;
                }
            } else {
                fieldSec.editable = false;
            }
            fieldSecList.add(fieldSec);
        }

        MetadataService.MetadataPort profileService = metadataService();
        List<MetadataService.ProfileTabVisibility> tvs = new List<MetadataService.ProfileTabVisibility>();
//        List<SaveResult> saveResultList = new List<SaveResult>();
        for(String profileName : profileNames) {
            String fullName = queryToolingApi(profileName);
            MetadataService.Profile profile = (MetadataService.Profile) profileService.readMetadata('Profile',new List<String>{fullName}).getRecords()[0];
            profile.tabVisibilities = tvs;
            profile.fieldPermissions = fieldSecList;
            List<MetadataService.UpsertResult> upsertResults = profileService.upsertMetadata(new List<MetadataService.Metadata>{profile});
            System.debug('upsertResults :: ' + upsertResults);
//            for(MetadataService.UpsertResult result : upsertResults) {
//                System.debug('profile result :: ' + result);
//                SaveResult saveResultObj = new SaveResult();
//                saveResultObj.type = 'profile';
//                saveResultObj.fullName = result.fullName;
//                if(result.errors != null) {
//                    System.debug('profile err :: ' + result.errors);
//                    saveResultObj.error = true;
//                    saveResultObj.success = false;
//                    saveResultObj.status = 'error';
//                    saveResultObj.message = result.errors[0].message;
//                } else {
//                    saveResultObj.error = false;
//                    saveResultObj.success = true;
//                    saveResultObj.status = 'success';
//                    saveResultObj.message = 'success';
//                }
//                saveResultList.add(saveResultObj);
//            }
        }
//        return saveResultList;
    }

    // 메타 데이터 API 커스텀 필드 삭제 메서드
    @AuraEnabled
    public static Map<String, Map<String, String>> deleteCustomFields(List<String> fieldNames) {
        Map<String, Map<String, String>> returnMap = new Map<String, Map<String, String>>();
        Boolean isError = false;
        try {
            MetadataService.MetadataPort metadataservice = metadataService();
            List<MetadataService.DeleteResult> results = metadataservice.deleteMetadata('CustomField', fieldNames);
            Map<String, String> errMap = new Map<String, String>();
            for(MetadataService.DeleteResult result : results) {
                System.debug(result);
                if(result.errors != null) {
                    System.debug('delete err :: ' + result.errors);
                    isError = true;
                    errMap.put(result.fullName, result.errors[0].message);
                }
            }
            if(!isError) {
                returnMap.put('success', null);
            } else {
                returnMap.put('error', errMap);
            }
        } catch (Exception e) {
            System.debug('err :: ' + e.getMessage() + ' || ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
        return returnMap;
    }

    /**
     * @description : Create MetadataService
     * @return : MetadataService.MetadataPort
     */
    private static MetadataService.MetadataPort metadataService() {
        String sessionId = getSessionId();
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = sessionId;
        return service;
    }

    /**
     * @description : Tooling API로 프로필 FullName 가져오는 메서드
     * @param profileName : 프로필 Name
     *
     * @return : 프로필 FullName
     */
    private static String queryToolingApi(String profileName) {
        String toolingApiEndpoint = Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v58.0/tooling';

        // Tooling API 쿼리
        String query = 'SELECT Id, Name, FullName FROM Profile WHERE Name = \'' + profileName + '\'';
        HttpRequest request = new HttpRequest();
        request.setEndpoint(toolingApiEndpoint + '/query?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + getSessionId());

        Http http = new Http();
        HttpResponse res = http.send(request);
        System.debug('Tooling API 응답: ' + res.getBody());

        String returnValue = '';
        if (res.getStatusCode() == 200) {
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug('resMap :: ' + resMap);
            List<Object> queryList = (List<Object>) resMap.get('records');
            Map<String, Object> recordsMap = (Map<String, Object>) queryList[0];
            returnValue = (String) recordsMap.get('FullName');
        } else {
            System.debug('Tooling API 오류 응답: ' + res.getStatusCode() + ' ' + res.getStatus());
            returnValue = null;
        }
        System.debug('returnValue :: ' + returnValue);
        return returnValue;
    }

    /**
     * @return Get 유저 세션
     */
    private static String getSessionId() {
        return Test.isRunningTest() ? UserInfo.getSessionId() : Page.GetSessionId.getContent().toString();
    }

}