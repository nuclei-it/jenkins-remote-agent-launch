Launch a Jenkins agent on a remote node by SSH.

This script uses the native `ssh` program rather than Jenkins' bundled SSH client. SSH client configs (`/etc/ssh/ssh_config` and `~/.ssh/config`) and credentials on the Jenkins host will be automatically used if set up.

# Usage

1. Clone or copy the `agent_launch.sh` onto the Jenkins host.
1. Confirm you can directly SSH to the target machine from the Jenkins host using the user Jenkins is running as, without using a password.
1. Add a new node to Jenkins with the following configuration:
    - Launch method: "Launch agent via execution of command on the controller"
    - Launch command: "bash path/to/agent_launch.sh"

# Why?

Jenkins has [a "Launch agents via SSH" plugin](https://github.com/jenkinsci/ssh-slaves-plugin), but it's not very flexible. You can only use fixed authentication material (username/password or username/private key) and you can't modify any other SSH config which might be required if you are working with some *enterprise software (TM)*.This script is a simple wrapper around `ssh` which makes it flexible. We can use more advanced authentication scheme (e.g. Kerberos over GSSAPI) rather than relying on what the Jenkins plugin provided.

Another advantage is that you can directly modify the connection process to add some custom provision commands, do some extended logging or execute optional environment checks. The node info is exposed via environment variables, so you are free to use them everywhere in the script.

## Is it secure enough to use username/password or username/private key?

No.

Jenkins, by default, is insecure. To name a few bad practices:

- [AAA is not enabled by default](https://www.jenkins.io/doc/book/security/access-control/#common-configuration-mistakes)
- [You can execute arbitrary commands on the Jenkins host](https://www.jenkins.io/doc/book/security/controller-isolation/#not-building-on-the-built-in-node)
- [Agents may execute arbitrary commands on the Jenkins host](https://www.jenkins.io/doc/book/security/controller-isolation/#agent-controller-access-control)

So we must make the worst assumption:

- Any command is executable by the Jenkins user on the Jenkins host will be executed
- Any file is readable by the Jenkins user on the Jenkins host will be read by any user

The SSH passwords and/or private keys, no matter in which way encrypted or scrambled, must be read and decrypted into plaintext by the Jenkins user, so the authentication could continue. Under the 2 assumptions we made before, you can be pretty sure an attacker is able to extract and reuse the passwords and/or private keys.

## How to mitigate the risks?

There are no method to completely mitigate the risks, because Jenkins is designed to be insecure and we can't change that without breaking too much functionality. But there are some things that you can do to improve the situation:

You should use a claim-based SSO protocol to login users to your Jenkins server. Also [set up authorization properly](https://www.jenkins.io/doc/book/security/access-control/#common-configuration-mistakes).

You should set up extensive remote logging and monitoring on the Jenkins host (the machine that runs the Jenkins service). Log every command executed on the host.

You should limit the Jenkins agent user from loginning from other hosts except the Jenkins host. This can be done by [setting up `AllowUsers` in SSH daemon config](https://linux.die.net/man/5/sshd_config) on each node. This ensures an attacker will not be able to extract the passwords or private keys and log onto the nodes from another device.

If your have the infrastrature at your hands, use GSSAPI to authenticate to the nodes instead of any secret materials that does not expire (passwords, private keys or host-based authentication). If you have Kerberos 5 (krb5) in your environment, refer to [contrib/kerberos/README.md](contrib/kerberos/README.md) for an example setup.

# FAQ

## Is the script secure?

The script does not handle any secret materials. The security of this method is entirely depend on what you've set up in your SSH configs (both client side and server side).
