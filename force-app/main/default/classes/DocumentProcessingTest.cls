/**
 
 */
@isTest
private class DocumentProcessingTest {
    @TestSetup
    static void makeData(){
        Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        List<Account> accountList = new List<Account>();
        List<Product2> produtsList = new List<Product2>();
        
        for(integer i=0;i<8;i++){
            Product2 prod = new Product2();
            Account acc = new Account();

            acc.RecordTypeId = prsnAccountRecTypeId;
            
            if(i<3){
                acc.firstName = 'Liqid BANK'+i;
                acc.lastName = 'Customer'+i;
                acc.personEmail = 'liqidtestbank'+i+'@test.com';

                prod.Name = ' Test Product Bank'+i;
                prod.Description='Test Product Entry For Bank Product';
                prod.productCode = 'LIQID-123'+i;
                prod.isActive = true;
                prod.Family = 'Midas Real Estate';

                
            }else if(i>2 && i < 6){
                acc.firstName = 'Liqid GWM'+i;
                acc.lastName = 'Customer'+i;
                acc.personEmail = 'liqidtestgwm'+i+'@test.com';

                prod.Name = ' Test Product GWM'+i;
                prod.Description='Test Product Entry For Bank Product';
                prod.productCode = 'LIQID-123'+i;
                prod.isActive = true;
                prod.Family = 'Midas Cash';

                
            }else{
                acc.firstName = 'Liqid INF'+i;
                acc.lastName = 'Customer'+i;
                acc.personEmail = 'liqidtestinf'+i+'@test.com';

                prod.Name = ' Test Product INF'+i;
                prod.Description='Test Product Entry For Bank Product';
                prod.productCode = 'LIQID-123'+i;
                prod.isActive = true;
                prod.Family = 'Midas Equity';

                
            }

            accountList.add(acc);
            produtsList.add(prod);
   
        }

        insert accountList;
        insert produtsList;
           
        
        List<Opportunity> opptysToInsert = new List<Opportunity>();
        
        for(Account acc : [Select Id,FirstName from Account]){
            Opportunity opp = new Opportunity();
            opp.AccountId = acc.Id;
            opp.Name = 'Test Opportunity '+acc.firstName;
            opp.CloseDate= System.Today();
            opp.StageName='Prospecting';
            opp.Pricebook2Id = Test.getStandardPricebookId();
            opptysToInsert.add(opp);
        }
        insert opptysToInsert;
          System.debug('>>>>> Opp asccount in test '+opptysToInsert.get(0).AccountId);

        List<PricebookEntry> priceBookEntriesList = new List<PricebookEntry>();
        for(Product2 prod : produtsList){
            
            PricebookEntry standardPrice = new PricebookEntry();
            standardPrice.Pricebook2Id = Test.getStandardPricebookId();
            standardPrice.Product2Id = prod.Id;
            standardPrice.UnitPrice = 200;
            standardPrice.IsActive = true;
            standardPrice.UseStandardPrice = false;
            priceBookEntriesList.add(standardPrice);

        }
       insert priceBookEntriesList;

        List<OpportunityLineItem> opptysLinesToInsert = new List<OpportunityLineItem>();
        List<Opportunity> insertedOppsList = [Select Id, Name ,AccountId From Opportunity];
        for(PricebookEntry pbe : priceBookEntriesList){
                integer index = 0;
                OpportunityLineItem oli = new OpportunityLineItem();
                Opportunity opp = insertedOppsList.size()>index ? insertedOppsList.get(index):insertedOppsList.get(0);
                System.debug('>>>>>> opp in TEST '+opp);
                oli.OpportunityId = opp.Id;
                oli.UnitPrice = 7500;
                oli.Quantity = 5;
                oli.PricebookEntryId = pbe.Id;
                opptysLinesToInsert.add(oli);

                
        }
        insert opptysLinesToInsert;

        List<Document__c> documentsToInsert = new List<Document__c>();
        List<OpportunityLineItem> insertedOppsLinesList = [Select Id, Opportunity.Name  From OpportunityLineItem];
        for(OpportunityLineItem oli : insertedOppsLinesList){
            System.debug('>>>>>> OLI in test'+oli);
            for(integer j=0;j<6;j++){
                Document__c doc = new Document__c();
                String entityType ;
                if(oli.Opportunity.Name.contains('Bank')){
                    entityType = 'Bank';
                }else if(oli.Opportunity.Name.contains('GWM')){
                    entityType = 'GWM';
                }else{
                    entityType = 'INF';
                }
                if(j<2){
                    doc.Name = entityType+' Legal doc'+j;
                    doc.Type__c = 'Legal';
                    doc.Notification_Status__c = 'New';
                    doc.Product__c = oli.Id;
                }
                else if(j < 4){
                    doc.Name = entityType+' Report doc'+j;
                    doc.Type__c = 'Report';
                    doc.Notification_Status__c = 'New';
                    doc.Product__c = oli.Id;
                }else{
                    doc.Name = entityType+' Transactional doc'+j;
                    doc.Type__c = 'Transactional';
                    doc.Notification_Status__c = 'New';
                    doc.Product__c = oli.Id;
                }
                
                documentsToInsert.add(doc);
            }
        }           
        insert documentsToInsert;


        List<User> usersToInsert = new List<User>();
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community user' LIMIT 1];
        for(Account acc : [Select Id,PersonContactId,FirstName,LastName,PersonEmail From Account Where Id IN:accountList]){
            user u = New User(
                UserName = acc.PersonEmail,
                FirstName = acc.FirstName,
                LastName = acc.LastName,
                Alias = (acc.FirstName).right(4),
                email = acc.PersonEmail,
                CommunityNickName = string.valueOf(math.random()).substring(0,6),
                ProfileID = communityProfile.id,
                TimeZoneSidKey = 'Europe/Berlin', 
                LocaleSidKey = 'en_US', 
                EmailEncodingKey = 'UTF-8', 
                LanguageLocaleKey = 'en_US',
                ContactID = acc.PersonContactId

            );
            usersToInsert.add(u);
        }
        insert usersToInsert;
        
              
    }
    @isTest
    static void positiveDocumentProcessingTest() {
        
        Test.startTest();
            ProcessDocumentsBatch docBatch= new ProcessDocumentsBatch();
            Id jobid= Database.executeBatch(docBatch,200);
        Test.stopTest();
        List<Document__c> docsList = [Select Id,Notification_Status__c,Customer_Notified_At__c from Document__c ];
        Assert.isTrue(!docsList.isEmpty(),'Docs not created');
        Assert.isTrue(docsList.get(0).Notification_Status__c == 'Customer Notified','Improper status added');  
        Assert.isTrue(docsList.get(0).Customer_Notified_At__c != null,'notification time not added');  

        docsList = [Select Id,Notification_Status__c,Customer_Notified_At__c from Document__c Where Notification_Status__c = 'New'];
        Assert.isTrue(docsList.isEmpty(),'Docs not updated');
        
    }

    @isTest
    static void partialDocumentProcessingTest() {
        List<Document__c> documentsList = [Select Id From Document__c];
        List<Document__c> docsToUpdate = new List<Document__c>();
        Integer counter = 0;
        for(Document__c doc : documentsList){
            
            if(counter < 3){
                Document__c docToUpdate = new Document__c(Id = doc.Id);
                docToUpdate.Notification_Status__c = 'Customer Notified';
                docsToUpdate.add(docToUpdate);
                counter++;
            }
        } 
        update docsToUpdate;
        Integer recordsToUpdate = documentsList.size() - docsToUpdate.size();
        List<Document__c> docsList = [Select Id,Notification_Status__c,Customer_Notified_At__c from Document__c Where Notification_Status__c = 'New' ];
        Assert.isTrue(docsList.size()== recordsToUpdate , 'No new status found in documents records');
        Test.startTest();
            ProcessDocumentsBatch docBatch= new ProcessDocumentsBatch();
            Id jobid= Database.executeBatch(docBatch,200);
        Test.stopTest();
        List<Document__c> docsListUpdated = [Select Id,Notification_Status__c,Customer_Notified_At__c from Document__c Where Notification_Status__c = 'New' ];
        Assert.isTrue(docsListUpdated.isEmpty(),'documents notification status are not updated ');
        
        
    }

    @isTest
    static void exceptionHandlingTest(){
        Account acc =  [Select Id From Account LIMIT 1]; 
        acc.PersonEmail = null;
        update acc;
        Test.startTest();
            ProcessDocumentsBatch docBatch= new ProcessDocumentsBatch();
            Id jobid= Database.executeBatch(docBatch,200);
        Test.stopTest();
        List<Log__c> logsList = [Select Id,Class_Name__c from Log__c];
        Assert.isTrue(!logsList.isEmpty(),'Log not created');
        Assert.isTrue(logsList.get(0).Class_Name__c == 'ProcessDocumentsBatch','Class name not updated in log');

    }
    @isTest
    static void testDocumentProcessScheduler(){
        String CRON_EXP = '0 0 9/12 1/1 * ? *';
        Test.startTest();
            String jobId = System.schedule('Document Processing Scheduler', CRON_EXP, new ScheduleDocumentProcessBatch());
        Test.stopTest();
        Integer executedJobs = [ SELECT count() FROM AsyncApexJob WHERE JobType = 'BatchApex' AND ApexClass.Name = 'ProcessDocumentsBatch'];
        Assert.isTrue(executedJobs == 1,  'The job not scheduled');


    }
}