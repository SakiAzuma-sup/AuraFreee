public with sharing class pdAccount2Freee {
    public virtual class BaseException extends Exception {}
    public class OtherException extends BaseException {}

    @AuraEnabled
    public static void account2Freee(Id accountId) {
        Freee_Info__c freeeInfo = Freee_Info__c.getOrgDefaults();
        if(String.isBlank(freeeInfo.Freee_Company_Id__c)) {
            throw new OtherException('Salesforceに事業所IDが設定されていません。');
        }
        
        Account acc = [
            select 
                Id,
                Name,
                BillingPostalCode,
                BillingState,
                BillingCity,
                BillingStreet,
                Phone,
                BankAccountKana__c,
                BankAccountName__c,
                BankAccountNumber__c,
                BankAccountType__c,
                BankBranchCode__c,
                BankBranchKana__c,
                BankBranchName__c,
                BankCode__c,
                BankName__c,
                BankNameKana__c,
                ContactName__c,
                ContactEmail__c,
                CountryCode__c,
                DefaultTitle__c,
                Sf_Account_Code__c,
                Freee_Partner_Id__c,
                LongName__c,
                NameKana__c,
                OrgCode__c,
                SendingMethod__c,
                Shortcut1__c,
                Shortcut2__c
            from 
                Account
            where
                Id = :accountId
        ];

        Integer companyId = getCompany(freeeInfo.Freee_Company_Id__c);

        if(!isExist(companyId, acc)) {
            registPartner(companyId, acc);
        } else {
            updatePartner(companyId, acc);
        }
    }

    private static Integer getCompany(String companyId) {    
        Http http = new Http();
        String path = 'callout:Freee/companies/' + companyId;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(path);
        req.setMethod('GET');

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return Integer.valueOf(companyId);
        }
        else {
            throw new OtherException(getApiErrorMessage(res.getBody()));
        }
    }

    private static Boolean isExist(Integer companyId, Account acc) {
        if(acc.Freee_Partner_Id__c == null) return false;

        Http http = new Http();
        String path = 'callout:Freee/partners/' + acc.Freee_Partner_Id__c;
        String parameters = 'company_id=' + companyId;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(path + '?' + parameters);
        req.setMethod('GET');

        HttpResponse res = http.send(req);
        if(res.getStatusCode() == 200) {
           return true;
        }
        else if(res.getStatusCode() == 404){
            return false;
        }
        else {
            throw new OtherException(getApiErrorMessage(res.getBody()));
        }
   }

    private static void registPartner(Integer companyId, Account acc) {
        Http http = new Http();
        String path = 'callout:Freee/partners';

        String parameters = createParameters(companyId, acc, /* isInsert = */ true);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(parameters);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 201) {
            Map<String, Object> mapBody = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> partner = (Map<String, Object>)mapBody.get('partner');

            Object partnerId = (Object)partner.get('id');
            acc.Freee_Partner_Id__c = String.valueOf(partnerId); 
            update acc;
        }
        else {
            throw new OtherException(getApiErrorMessage(res.getBody()));
        }
   }

    private static void updatePartner(Integer companyId, Account acc) {
        Http http = new Http();
        String path = 'callout:Freee/partners/code/' + acc.Sf_Account_Code__c;

        String parameters = createParameters(companyId, acc, /* isInsert = */ false);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(path);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(parameters);


        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new OtherException(getApiErrorMessage(res.getBody()));
        }
   }
    
    private static String getApiErrorMessage(String body) {
        Map<String, Object> mapError = (Map<String, Object>)JSON.deserializeUntyped(body);
        List<Object> lstError = (List<Object>)(mapError.get('errors'));
        String errorMessage = 'Freee APIでエラーが発生しました\n';
        if(lstError != null) {
            for(Object mapErrorContent : lstError) {
                List<Object> lstMessage = (List<Object>)((Map<String, Object>)mapErrorContent).get('messages');
                for(Object message : lstMessage) {
                    errorMessage += message.toString() + '\n';
                }
            }            
        } else {
            String message = (String)((Map<String, Object>)mapError).get('message');
            errorMessage += message + '\n';
        }
        return errorMessage;
    }

    private static String createParameters(Integer companyId, Account acc, Boolean isInsert) {
        String parameters = '{';
        parameters += '"company_id": ' + companyId + ',';
        parameters += '"name": "' + acc.Name + '",';

        if(isInsert) {
           parameters += '"code": "' + acc.Sf_Account_Code__c + '",';        
        }

        parameters += '"shortcut1": "' + (String.isBlank(acc.Shortcut1__c) ? '' : acc.Shortcut1__c) + '",';
        parameters += '"shortcut2": "' + (String.isBlank(acc.Shortcut2__c) ? '' : acc.Shortcut2__c) + '",';

        Integer orgCode = getOrgCode(acc.OrgCode__c);
        parameters += '"org_code": ' + orgCode + ',';

        String countryCode = getCountryCode(acc.CountryCode__c);
        if(countryCode != null) {
            parameters += '"country_code": "' + (String.isBlank(countryCode) ? '' : countryCode) + '",';
        }

        parameters += '"long_name": "' + (String.isBlank(acc.LongName__c) ? '' : acc.LongName__c) + '",';
        parameters += '"name_kana": "' + (String.isBlank(acc.NameKana__c) ? '' : acc.NameKana__c) + '",';
        parameters += '"default_title": "' + (String.isBlank(acc.DefaultTitle__c) ? '' : acc.DefaultTitle__c) + '",';
        parameters += '"phone": "' + (String.isBlank(acc.Phone) ? '' : acc.Phone) + '",';
        parameters += '"contact_name": "' + (String.isBlank(acc.ContactName__c) ? '' : acc.ContactName__c) + '",';
        parameters += '"email": "' + (String.isBlank(acc.ContactEmail__c) ? '' : acc.ContactEmail__c) + '",';
        parameters += '"address_attributes": {';
        parameters += '"zipcode": "' + (String.isBlank(acc.BillingPostalCode) ? '' : acc.BillingPostalCode) + '",';

        Integer prefCode = getPrefCode(acc.BillingState);
        if(prefCode != null) {
            parameters += '"prefecture_code": ' + prefCode + ',';
        }

        if(String.isBlank(acc.BillingStreet)) {
                parameters += '"street_name1": "' + (String.isBlank(acc.BillingCity) ? '' : acc.BillingCity) + '",';
                parameters += '"street_name2": ""';
        } else {
            String[] billingStreet = acc.BillingStreet.split('\r\n');
            if(billingStreet.size() >= 2) {
                parameters += '"street_name1": "' + (String.isBlank(acc.BillingCity) ? '' : acc.BillingCity) + (String.isBlank(billingStreet[0]) ? '' : billingStreet[0]) + '",';
                parameters += '"street_name2": "' + (String.isBlank(billingStreet[1]) ? '' : billingStreet[1]) + '"';
            } else if (billingStreet.size() == 1) {
                parameters += '"street_name1": "' + (String.isBlank(acc.BillingCity) ? '' : acc.BillingCity) + (String.isBlank(billingStreet[0]) ? '' : billingStreet[0]) + '",';           
                parameters += '"street_name2": ""';
            }
        }
        parameters += '},';

        String sendingMethod = getSendingMethodCode(acc.SendingMethod__c);
        if(sendingMethod != null){
            parameters += '"partner_doc_setting_attributes": {';
            parameters += '"sending_method": "' + (String.isBlank(sendingMethod) ? '' : sendingMethod) + '"';
            parameters += '},';
        }

        parameters += '"partner_bank_account_attributes": {';
        parameters += '"bank_name": "' + (String.isBlank(acc.BankName__c) ? '' : acc.BankName__c) + '",';
        parameters += '"bank_name_kana": "' + (String.isBlank(acc.BankNameKana__c) ? '' : acc.BankNameKana__c) + '",';
        parameters += '"bank_code": "' + (String.isBlank(acc.BankCode__c) ? '' : acc.BankCode__c) + '",';
        parameters += '"branch_name": "' + (String.isBlank(acc.BankBranchName__c) ? '' : acc.BankBranchName__c) + '",';
        parameters += '"branch_kana": "' + (String.isBlank(acc.BankBranchKana__c) ? '' : acc.BankBranchKana__c) + '",';
        parameters += '"branch_code": "' + (String.isBlank(acc.BankBranchCode__c) ? '' : acc.BankBranchCode__c) + '",';

        String accountType = getBankAccountType(acc.BankAccountType__c);
        if(accountType != null) {
            parameters += '"account_type": "' + (String.isBlank(accountType) ? '' : accountType) + '",';
        }

        parameters += '"account_number": "' + (String.isBlank(acc.BankAccountNumber__c) ? '' : acc.BankAccountNumber__c) + '",';
        parameters += '"account_name": "' + (String.isBlank(acc.BankAccountKana__c) ? '' : acc.BankAccountKana__c) + '",';
        parameters += '"long_account_name": "' + (String.isBlank(acc.BankAccountName__c) ? '' : acc.BankAccountName__c) + '"';
        parameters += '}';
        parameters += '}';
        return parameters;        
    }

    private static Integer getOrgCode(string orgName) {
        List<String> orgNames = new List<String> {
            '法人',
            '個人'
        };

        Integer orgCode = null;
        for(Integer i = 0 ; i < orgNames.size() ; i++) {
            if(orgNames[i] == orgName) {
                orgCode = i + 1;
                break;
            }
        }

        return orgCode;
    }    

    private static String getCountryCode(string countryName) {
        if(countryName == '国内') return 'JP';
        else if(countryName == '国外') return 'ZZ';
        return null;
    }    
    
    private static String getSendingMethodCode(string sendingMethodName) {
        if(sendingMethodName == 'メール') return 'email';
        else if(sendingMethodName == '郵送') return 'posting';
        else if(sendingMethodName == 'メールと郵送') return 'email_and_posting';
        return null;
    }    
    
    private static String getBankAccountType(string bankAccountTypeName) {
        if(bankAccountTypeName == '普通') return 'ordinary';
        else if(bankAccountTypeName == '当座') return 'checking';
        else if(bankAccountTypeName == '納税準備預金') return 'earmarked';
        else if(bankAccountTypeName == '貯蓄') return 'savings';
        else if(bankAccountTypeName == 'その他') return 'other';
        return null;
    }    
    
    private static Integer getPrefCode(String prefName) {
        List<String> pref = new List<String> {
            '北海道',
            '青森県',
            '岩手県',
            '宮城県',
            '秋田県',
            '山形県',
            '福島県',
            '茨城県',
            '栃木県',
            '群馬県',
            '埼玉県',
            '千葉県',
            '東京都',
            '神奈川県',
            '新潟県',
            '富山県',
            '石川県',
            '福井県',
            '山梨県',
            '長野県',
            '岐阜県',
            '静岡県',
            '愛知県',
            '三重県',
            '滋賀県',
            '京都府',
            '大阪府',
            '兵庫県',
            '奈良県',
            '和歌山県',
            '鳥取県',
            '島根県',
            '岡山県',
            '広島県',
            '山口県',
            '徳島県',
            '香川県',
            '愛媛県',
            '高知県',
            '福岡県',
            '佐賀県',
            '長崎県',
            '熊本県',
            '大分県',
            '宮崎県',
            '鹿児島県',
            '沖縄県'
        };

        Integer prefCode = null;
        for(Integer i=0 ; i<pref.size() ; i++) {
            if(pref[i] == prefName) {
                prefCode = i;
                break;
            }
        }

        return prefCode;
    }
}
