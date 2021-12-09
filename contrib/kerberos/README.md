This doc assume you have some knowledge of Kerberos 5 and have a KDC available.

# Why use such a complicated method?

We used to use SSH pubkey authentication. While this is a lot better than embedding a plaintext password somewhere, it has a lot downsides:

1. `authorized_keys` relies largely on the storage mounted on a certain machine. And we use shared NFS storage, so it implies we have to control which machines the `jenkins` user can access via which NFS directory we mount (which is a really weird thing if you ever think about it)
2. Jenkins is designed with NO security in mind. Jenkins by default allow any user to run random commands on the host (!) and we still have legacy pipelines that depends on this "feature". This means all the files accessible by the Jenkins server will be accessible by any users who are able to log into Jenkins. So anything that can be accessed by the Jenkins server (I mean, any fixed material you use to authenticate to another machine) can be stole by anybody and used elsewhere.

So we really need an advanced authentication scheme which:

1. Does not rely on a file on the destination machine to authenticate a user (detach storage from AAA)
2. Does not have a fixed credential material user can steal and use forever (an authenticated user might still steal the temporary credential and use it in a fixed time, as this is equal to directly running commands on the Jenkins host node; but when that user is denied from loginning to Jenkins, after a few hours the credential will expire)
3. Stop a malicious user from stealing a set of credential and use it elsewhere

# Security Consideration

Keytab is a fixed credential material which you can use to exchange for a time-limited TGT. The keytab file is only accessable by root, and the Jenkins user can only get the automatically renewed TGT.

Remember:

- Keytab == password, just in a more obsecured form. Generate it only from a secure environment. Keep it secure.
- Keytab should not be accessed by the actual user to prevent persistent credential stealing. (Always remember: Jenkins users can execute malicious commands directly on the Jenkins host.) It's recommended to keep the keytab visible only on root account.
- Proxible tickets are intentionally disabled to limit an attacker from lateral movement. You can only access one level of servers from the Jenkins host; you cannot jump to a second hop.

# Deployment

Requirements:
- There need to be a service account (can be any type of account) for Jenkins to authenticate against AD.
- The service account's password is not important, so it is recommended not to remember it; you might reset the password everytime if you want a new keytab. Note that if the password is reset, every keytab associated with this account need to be regenerated or copied.
- The machine itself doesn't need to be joined to AD.
- Start the Jenkins server only under the service account.

First we need to ensure Kerberos config (`/etc/krb5.conf`) is correct, so the host can find KDC. An example is provided in this repo.

Then we'll need a few packages:
```shell
yum install krb5-user kstart
```

Let's generate a keytab for the designated user:
```shell
ktutil
add_entry -password -p jenkins@CORP.CONTOSO.COM -k 1 -e aes256-cts-hmac-sha1-96
write_kt /etc/krb5-jenkins.keytab
quit

chown root:root /etc/krb5-jenkins.keytab
chmod 600 /etc/krb5-jenkins.keytab
```
(Note: you might change KVNO to be larger than 1)

Then set up `k5start` to automatically acquire TGT:
```shell
cp k5start-jenkins.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now k5start-jenkins
```

Also, the SSH client config might be tweaked to enable Kerberos authentication with GSSAPI. There is a reference config file in this repo.

Finally, verify everything is intact:
```shell
su - jenkins

klist
# you should be able to see at least one valid ticket

ssh -o PreferredAuthentications=gssapi-with-mic -vvvvv jenkins-node-1.corp.contoso.com
# should work
```
