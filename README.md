# wstools

## Summary
This is a collection of shell functions/commands to assist with the 
day-to-day management of Linux workstations. 

## Getting started

The first step is to load the workstation commands into the environment 
by typing this command at the prompt (when logged in as root) and running
the bash shell.

```bash
source wstools.bash
```

## User creation commands

### newuser

This command creates a new user whose user id is known to the Identity Management
systems. That is, the user's
login uses their netid/password as defined by Kerberos, AD, LDAP, etc. 
The syntax is straightforward:

```bash
newuser username
```

`newuser` performs these steps:

- It first determines if the username is a netid currently known to the Identity 
  Management systems. This is the common case --- adding students' netids 
  to the lab.
- The uid associated with the netid is determined.
- The user is created with the appropriate uid and primary group (`users`).
- A home directory that is group readable is created.

The user will be able to login with the SSO password
associated with the netid. If the username is a local user, a password must be assigned
with the `passwd` command.

### newusers

This command creates several users at once with calling newuser in a loop. The 
syntax is similarly straightforward.

```bash
newusers username1 username2 username3 ...
```

### newusers_remote

This command works like newusers, but the users are created on a specified
workstation. The workstation name is given before the first user name:

```bash
newusers_remote host username1 username2 ...
```

`host` is usually the name of a workstation, i.e., the value you get from
the `hostname` command. If `host` is the literal value `all`, the the command 
is executed on all the workstations in the group.

```bash
newusers_remote all username1 username2 ...
```

### The list of workstations

`all` is not the name of a workstation! Instead, `all` substitutes the
value of an environment variable named `$my_computers` that is set in 
the login script. In `csh`, 

```csh
setenv my_computers "adam anna boyi cooper dirac elion \
   evan franklin hamilton irene justin marie mayer pople sarah thais " 
```

or in `bash`

```bash
export my_computers="adam anna boyi cooper dirac elion \
   evan franklin hamilton irene justin marie mayer pople sarah thais " 
```

In `wstools.bash` this environment variable is set only in cases
where no previous value has been assigned.

## A full example

Let's look at how this would work from adam using netids from an addition at the beginning of the Spring 2023 term.
The student id was `cb9sy`. Login to `root@adam`. Source the `wstools.bash` file.

```bash
[root@adam ~]# source wstools.bash
```

Note that the prompt changes slightly so that you can tell that you have sourced wstools.
```bash
[adam(root):~]:
```

Let's start by adding cb9sy to adam and see what happens:

```bash
[adam(root):~]: newuser cb9sy
User cb9sy found in LDAP with id uid=293622(cb9sy) gid=100(users) groups=100(users)
cb9sy has been added.
```

We have only one user, so newusers should not give us anything different:

```bash
[adam(root):~]: newusers cb9sy
User cb9sy found in LDAP with id uid=293622(cb9sy) gid=100(users) groups=100(users)
cb9sy has been added.
```

Note that it does no harm to add a user who already exists. 
Now, let's do the complete creation with a user known to exist on some 
workstations and not others:


Note also that the script circumvents (but reports) several common problems:

- If a workstation cannot be found (perhaps the name is misspelled?), `newusers_remote` 
will move on to the next workstation after noting the error.
- If a workstation is offline, newusers_remote will not hang. `newusers_remote` gives 
up after 5 seconds. NOTE: this wait time can be changed in the `wstools.bash` file.
- If a user already exists or has a home directory (ex: a user is being reactivated), 
`newusers_remote` mentions this fact and moves on.

## Keeping wstools up to date

`wstools` is delivered as a part of a tarball with several other supporting 
utilities. This tarball is `wstools.tar`, and it has everything needed in it.

When the list of workstations changes, the `wstools.bash` file will need 
editing. There is a command provided to keep `wstools` up to date. After 
the editing, and whatever testing is done to ensure the changes work as 
intended, this command will rebuild the tarball, and reload the commands 
from `wstools.bash` into the environment.

```bash
wstools update
```

The tarball can be delivered to another computer with the `push` command. 

```bash
wstools push newton
```

And it can be pushed to all the workstations at once with the all variant.

```bash
wstools push all
```
