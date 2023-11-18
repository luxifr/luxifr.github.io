---
title: "AWS Lambda invocation error decrypting environment"
date: 2023-11-17T23:16:51Z
tags:
  - AWS
  - Serverless
  - Lambda
  - Bug
description: |
  AWS Lambda fails to invoke because it cannot decrypt its environment
  variables, despite using the AWS-managed key, which supposedly automagically
  works.
image: screenshot.png
---

I've helped out one of our dev teams over the past couple of days regarding an
AWS Lambda function that they just could not invoke. The reason it took so long
was that I had to involve AWS support to clarify what the actual issue was.

AWS Lambda fails to invoke because it cannot decrypt its environment variables,
despite using the AWS-managed key, which supposedly automagically works.

## tl;dr

Can't invoke a Lambda because it can't decrypt its environment variables
despite using the AWS-managed key? Chances are you've deleted and recreated its
execution role (with the same name). To fix this: change the execution role to
something else and back to the one you (ostensibly) had it set to.

## What happened?

The team deployed a Lambda function via an IaC pipeline to several
environments. However, all things ostensibly being equal, the function would
just not invoke in one of them. The error message above is pretty clear about
what happens.

So I checked on the configuration of the environment variable encryption and it
was set to use the AWS-managed (owned by the Lambda service itself) KMS key.
Given [you cannot *disable* encrpytion at
rest](https://docs.aws.amazon.com/lambda/latest/dg/security-dataprotection.html#security-privacy-atrest)
for environment variables in Lambda at all, you'd think the execution role just
needs the correct policies attached to allow using the correct key for
encryption, right?

Turns out you don't even need to do that (which explains why I would never have
seen that in the past using those defaults), because [Lambda will do that for
you](https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html#configuration-envvars-encryption)
under the covers:

> Lambda always provides server-side encryption at rest with an AWS KMS key.
> By default, Lambda uses an AWS managed key. If this default behavior suits
> your workflow, you don't need to set up anything else. Lambda creates the AWS
> managed key in your account and manages permissions to it for you. AWS
> doesn't charge you to use this key.

**So what gives?**

## It's a bug, not a feature

Turns out, you can somehow create a scenario whereby you delete the execution
role of the Lambda and then recreate one with the same name. That new role
would look perfectly attached to your Lambda function looking at the config in
the console. However, of course the canonical principal ID of the new role
would be different from the old one. Since in this situation you would not
actually have attached that new role, AWS Lambda's internal automation to
permit it access to the key would not kick in, leaving the old ID in its key
policy, leading to this error.

Here's what the told me, verbatim:

> Whenever you are using AWS Managed KMS keys to encrypt (at rest) your
> function's environment variables, your function execution role does not require
> any permission policy to be added. It is because Lambda automatically grants
> permission for the execution role (Principal ID of the role, example -
> AROAUISMSUAFGSFHSJDJURKJ) in the AWS Managed KMS Key policy as Principal ID is
> unique for each role. This is as per the service design which works under the
> hood.
>
> However, when we delete and re-create Lambda function's execution role keeping
> the same name, even though the name and ARN remains same, the Principal ID of
> this IAM role changes in the background and this role gets a new unique ID.
> Now, as per the updated AWS Managed KMS Key key policy (which can't be edited
> by end user as it is maintained by the service), whenever Lambda tries to
> decrypt environment variables using the function execution role with different
> Principal ID, KMS service denies the request as it cannot recognize the new ID.
>
> In order to overcome this issue, you have to update the function role to a
> different execution role and then immediately revert it back to the role that
> you are using. To simplify, if your function say funcA is using a role1 which
> was deleted and recreated, you update your function role to another role say
> role2 and then you need to update it back to role1.

It took quite a bit of back and forth with the AWS support to get to this
point, including some misunderstandings as to what the actual problem was,
leading to some frustration and dragging on of the issue for a bit. And while I
understand the technical explanation they gave me in the end, I'd consider this
a bug in Lambda because the mechanism is hidden away from the user and the
error message didn't make sense based on what you can gather from the
documentation. Maybe they'll improve on this edge case in the future 🤷🏼‍♀️.
