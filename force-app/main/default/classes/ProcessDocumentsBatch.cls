/*
    Class Name : ProcessDocumentsBatch
    Description : This is a class which implements a batch process which gets all the documents with 'New' status and if such documents 
    found then sends email to the customer and update thos e documents
    Test Class : DocumentProcessingTest

*/
public class ProcessDocumentsBatch implements  Database.Batchable<sObject> {
    public static final string DOCUMENT_STATUS_NEW = 'New';
    public static final string DOCUMENT_STATUS_CUSTOMER_NOTIFIED = 'Customer Notified';

    
    /*
        @param :
        BC : Batchable context variable
        @description:
        This method is return a query locator with scoped data of all Document__c object which are having the Notification_Status__c = 'New'
    */
    public Database.queryLocator start(Database.BatchableContext BC){
        String query = 'SELECT Id,Name,Type__c,Product__r.Opportunity.Account.PersonEmail,Product__r.Opportunity.Account.PersonContactId FROM Document__c WHERE Notification_Status__c =:DOCUMENT_STATUS_NEW ';
        return Database.getQueryLocator(query);
    }

    /*
        @param :
        BC : Batchable context variable
        scope : all the result returned by the start method
        @description:
        This method is processing all the documents and based on the target docs it classify them according to their type and their recipient 
        and then per receipient it send emails per doc type which contain list of  all doc name of same type
    */
    public void execute (Database.BatchableContext bc ,List<sobject> scope){
        /*
        Example Data set 
            Doc     Type        Account Email 
        ======================================================
            Doc1   Report       Prod1->Opp->AccountEmail1
            Doc2   Report       Prod1->Opp->AccountEmail1
            Doc4   Report       Prod2->Opp->AccountEmail2
        =======================================================
            Doc3   Trasaction   Prod1->Opp->AccountEmail1
            Doc6   Trasaction   Prod3->Opp->AccountEmail3
        =======================================================
            Doc3   Contract     Prod1->Opp->AccountEmail1
            Doc7   Contract     Prod3->Opp->AccountEmail3
            Doc8   Contract     Prod2->Opp->AccountEmail2
        =======================================================
            Doc5   Legal        Prod2->Opp->AccountEmail2    

        * */
        Map<String,Map<String,List<Document__c>>> documentsByTypeByEmailMap = new Map<String,Map<String,List<Document__c>>>(); 
        List<Document__c> docsToUpdate  = new List<Document__c>();

        /* Below code is processing all the documents to fill documentsByTypeByEmailMap with following structure
                PersonEmail1 
                    Report
                        Doc 1
                        DOc 2
                    Transactional
                        Doc 3
                        DOc 4      
    */ 
        for(Document__c doc : (List<Document__c>) scope){
            String email = doc.Product__r.Opportunity.Account.PersonEmail;
            Map<String ,List<Document__c>> docsListByType =   documentsByTypeByEmailMap.get(email);
            
            if(docsListByType == null){
                docsListByType = new Map<String ,List<Document__c>>();
                documentsByTypeByEmailMap.put(email,docsListByType);
            }
            if(docsListByType.get(doc.Type__c) == null){
                List<Document__c> docsList = new List<Document__c>();
                docsListByType.put(doc.type__c,docsList);
            }
            docsListByType.get(doc.type__c).add(doc);  
        }

        //below map is to get user id for the person contact id which will be used as target object id in Email Message
        Map<String,Id> emailTouserIdMap = new Map<String,Id>();
        List<User> portalUsersList = [SELECT Id,email from User WHERE email IN :documentsByTypeByEmailMap.keySet()];
        for(User u : portalUsersList){
            emailTouserIdMap.put(u.email,u.id);
        }
        List<Messaging.SingleEmailMessage> emailsToSendList = new List<Messaging.SingleEmailMessage>();
        for(String accEmail : documentsByTypeByEmailMap.keySet()){
            Map<String,List<Document__c>> docsByTypeMapIter = documentsByTypeByEmailMap.get(accEmail);
            emailsToSendList.addAll(prepareEmail(emailTouserIdMap.get(accEmail),docsByTypeMapIter,docsToUpdate));
        }
        try{
            Messaging.sendEmail(emailsToSendList);
            if(!docsToUpdate.isEmpty()){
                update docsToUpdate;
            }
        }catch(Exception e){
            Log__c log = new Log__c();
            log.Class_Name__c = 'ProcessDocumentsBatch';
            log.Method_Name__c = 'execute';
            log.Message__c = e.getMessage();
            log.Stack_Trace__c = e.getStackTraceString();
            insert log;
        }
        
    }

    /*
        @param :
            userId : User related to person contact 
            docsListByTypeMap : all documents relatd to a particular doc type in a Map<DocTypeName,Related Docs List>
            docsToUpdate : referenced lsit of docs which need to be updated in method below and later updated in execute call
        @description:
            This method is used to prepare all the emails which are related to a document type 

        @return 
            a lsit of Messaging.SingleEmailMessage that conatains all the messages created per doc type
    */
    public List<Messaging.SingleEmailMessage> prepareEmail( Id userId, Map<String,List<Document__c>> docsListByTypeMap,List<Document__c> docsToUpdate){
        Id personContactId ;
        System.debug('>>>> user Id  frommap'+userId);
        List<Messaging.SingleEmailMessage> emailsToSendList = new List<Messaging.SingleEmailMessage>();
        for(String docType:docsListByTypeMap.keySet()){
            // one email per type creation
            Messaging.SingleEmailMessage emailToSend = new Messaging.SingleEmailMessage();
            emailToSend.setSubject('Summary for : ' + docType);
            String htmlBody = '<div> <b>Here is the list of document </b><br></br></div>';
            htmlBody+='<table border="1" style="border-collapse:collapse"><tr><td>Document Name</td></tr>';
            for(Document__c doc : docsListByTypeMap.get(docType)){
                if(personContactId == null){
                    personContactId = doc.Product__r.Opportunity.Account.PersonContactId;
                }
                htmlBody+= '<tr><td>'+doc.Name+'</td></tr>';
                docsToUpdate.add(new Document__c(id=doc.id,Customer_Notified_At__c = System.now(),Notification_Status__c=DOCUMENT_STATUS_CUSTOMER_NOTIFIED));
            }
            htmlBody+='</table>';
            emailTosend.setSaveAsActivity(false);
            emailToSend.setTargetObjectId(userId);
            emailToSend.setHtmlBody(htmlBody);
            emailsToSendList.add(emailToSend);

        }
        return emailsToSendList;
    }

    /*
        @param
                BC :Batchabale context
        @description 
            Can be used for post processing once all the batches are finished .
    */
    public void finish(Database.BatchableContext BC){
       
    }
}