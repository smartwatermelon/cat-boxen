# cat-boxen
###### An enumerator which grabs and outputs information from our Android and iOS build nodes.

> Slackday 2018 Project by Andrew Rich <arich@slack-corp.com> & Lydia Joslin <ljoslin@slack-corp.com>
## Prerequisites
* This tool assumes you have the authentication token variables `TOKEN_SMITHERS` and `TOKEN_SMITHERS_STAGING` set in your environment. 
* If you do not have these variables already set in your development environment, you may grab the values from line 40 in [config_smithers.pl](https://slack-github.com/slack/chef-repo/blob/master/site-cookbooks/slack-apache/files/default/tsauth/config_smithers.pl#L40).

## Usage 

* Run the tool: `./cat-boxen` -- it doesn't care about your current working directory.
* You can then copy the updated IP addresses into your `/etc/hosts` file.

## Demo Mode
* Run the demo wrapper: `./cat-boxen-demo`. Press any key to stop the demo.
<br/><br/>
<br/><br/>

_"I'm fairly terrified that you implemented 'DNS over Jenkins.'" -- Richard Crowley_
