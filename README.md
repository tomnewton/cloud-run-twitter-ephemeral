# Twitter ephemerality for Cloud Run

### What does this do? 

This is a ruby script that is runnable on Google Cloud Platform's new service Google Cloud Run. This repo demonstrates how you can create an inexpesive scheduled task to remove tweets from your timeline that are a certain age. 

To accomplish this we make use of the following services: 

- Google Cloud Scheduler
- Google Cloud Pub/Sub
- Google Cloud Run

We'll use the `gcloud` command line tool as much as possible to get this all running. 

## How do I run this? 

1. Install the `gcloud` command line tool. Then run: 

```bash
  gcloud components install
  gcloud components update
```
2. Setup a new project in the Google Cloud Console. 

```bash
gcloud projects create my-example-project-id --name="my test project" --set-as-default
```
3. Enable billing for your project by following these [instructions](https://cloud.google.com/billing/docs/how-to/modify-project#enable_billing_for_a_new_project).

3. Enable the services we need for this project.
```bash
 gcloud services enable pubsub
 gcloud services enable cloudscheduler.googleapis.com
 gcloud services enable run.googleapis.com
```

4. Create the pubsub topic
```bash
  gcloud pubsub topics create run-trigger
```

5. Go to developers.twitter.com and create an application, and get your authentication credentials. 

6. Build this project and ship it to Google Container Registry. You must provide Environment Variables for the following keys: 
```bash
  gcloud builds submit --tag gcr.io/[PROJECT-ID]/[IMAGE]
```

7. Now you'll actually setup the Cloud Rub service. 

- TWITTER_CONSUMER_KEY
- TWITTER_CONSUMER_SECRET
- TWITTER_ACCESS_TOKEN
- TWITTER_ACCESS_TOKEN_SECRET
- RUN_PROJECT_ID - use the friendly name you gave your project in step 2 (--name=)

[IMAGE] - arbitrary name - you'll need this later though.
[PROJECT-ID] - the google project id.
[YOUR_SERVICE_NAME] - whatever you want to call the Cloud Run Service

```bash
  gcloud config set run/region us-central1
  gcloud beta run deploy [YOUR_SERVICE_NAME] --image gcr.io/tn-test-project-99/runservice --update-env-vars RUN_PROJECT_ID=YOUR_PROJECT_ID,TWITTER_CONSUMER_KEY=VALUE1,TWITTER_CONSUMER_SECRET=VALUE2,TWITTER_ACCESS_TOKEN=VALUE3,TWITTER_ACCESS_TOKEN_SECRET=VALUE4 --quiet
```

When this has finished you'll see output from the `gcloud` tool that looks like: 

```bash
Deploying container to Cloud Run service [runservice] in project [tn-test-project-99] region [us-central1]
✓ Deploying new service... Done.                                                                                                                                                                                            
  ✓ Creating Revision...                                                                                                                                                                                                    
  ✓ Routing traffic...                                                                                                                                                                                                      
Done.                                                                                                                                                                                                                       
Service [runservice] revision [runservice-00001] has been deployed and is serving traffic at https://runservice-xtu6b5owbq-uc.a.run.app
```

You'll need the url `https://runservice-xtu6b5owbq-uc.a.run.app` at the end for step 9.

8. Go [here](https://console.cloud.google.com/iam-admin/serviceaccounts) and create a new service account. Call it `cloud-run-invoker`, click create, then give it the `role` of `Cloud Run Invoker` in the drop down list. You don't need to create any keys for this account. Now copy the email address associated with the new service account which should look something like: cloud-run-invoker@[project-id].iam.gserviceaccount.com	

9. We now have to create the PubSub subscription, that will call our Cloud Run service. Remember we named our PubSub topic `run-trigger` we'll use that now and tell our subscription to impersonate the service account when calling our push endpoint ( our Cloud Run service ). 

```bash
gcloud pubsub subscriptions create [SUBSCRIPTION_NAME] --topic run-trigger --topic-project=[PROJECT-ID] --ack-deadline=20 --push-endpoint=[URL_FROM_LAST_STEP] --impersonate-service-account=[SERVICE-ACCOUNT-EMAIL]
```

10. Go [here](https://console.cloud.google.com/cloudscheduler) and create a new job. Give it a name, and choose `pubsub` as the target, and enter in our pubsub topic name from step 4, which we called 'run-trigger'. Go ahead and setup a schedule, something like: '0 9 * * 1' should work - 9am every Monday morning.

11. You're done.