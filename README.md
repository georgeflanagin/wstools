# wstools

## Summary
This is a collection of shell functions/commands to assist with the 
day-to-day management of Linux workstations. 

## Getting started

The first step is to load the workstation commands into the environment by typing this command at the prompt (when logged in as root):

```bash
source wstools.bash
```

## User creation commands

### newuser
This command creates a new user. It can create both entirely local 
users (i.e., system users known only on this computer) and users who 
login using their netid/password as defined by Kerberos, AD, LDAP, etc. 
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
- If the username is not a valid netid, newuser creates a local user.

If the username is a known netid, the user will be able to login with the SSO password
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
