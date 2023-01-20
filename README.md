# wstools

## Summary
This is a collection of shell functions/commands to assist with the 
day-to-day management of Linux workstations. 

## Getting started

The first step is to load the workstation commands into the environment 
by typing this command at the prompt (when logged in as root):

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

all reads an environment variable that is set at the top of the `wstools.bash` file:

```bash
export carols_computers="adam anna boyi cooper dirac elion \
   evan franklin hamilton irene justin marie mayer pople sarah thais " 
```

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


Note that the script circumvented several common problems:

- One of the workstations had a name that could not be found, and newusers_remote skipped over it with no complaints.
- The host named franklin was offline. Rather than stalling out and hanging, newusers_remote gave up after 5 seconds. NOTE: this can be changed in the wstools.bash file.
-	On two workstations, gflanagi existed and was a member of another group (exx). The group information was updated.

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
wstools push justin
```

And it can be pushed to all the workstations at once with the all variant.

```bash
wstools push all
```
