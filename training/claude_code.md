# General unstructured notes

PRD = Product Requirements Document
>> Create a ToDo List

> Feature > Test > Complete
> Next Feature

---

Use the Claude Code `AskUserQuestion tool `

---

1. I want to build a CDK application to deploy Zabbix server in AWS as Fargate Tasks. Please help me create a plan. Write this plan in a prd.md
2. I reviewed the PRD. We must make the solution internal facing with the ALB, so it is only available via VPC.
3. Interview me and use the `AskUserQuestion` tool, to make the prd complete
4. Read this plan and interview me in detail using `AskUserQuestionTool` about literally anything; technical implementation, UI & UX, concerns, tradeoffs, etc.
5. We have created a prd.md file, what should be our next step to create good code.
  I know that we need to follow a development process of "> Feature > Test > Complete > Next Feature" but I do not know where to start.
  I know thing need a progress.txt also, to track our progress and ensure we do not jump ahead of ourselves
6. How do we define the "Test" part of our workflow?
  Should we define functional tests before, or is the test designed as part of the feature step?
7. How do we ensure that you follow the procedure correctly, and test properly?
8. how can we validate that running npm test will actually execute tests, and not do the equivalent of "echo tests succesful"
9. as we are building CDK, we should also perform a cdk synth
10. once a feature is "complete" we should test it by performing a cdk deploy. We have an AWS CLI profile with the profile name "developer-account" that we can use.
  Once a feature is written, passes assertion tests, succesfully completes a CDK synth, and is deployed to dev using the "developer-account" aws cli profile, we must commit it to git. There is no remote server, so we only need to
  commit, we cannot push.