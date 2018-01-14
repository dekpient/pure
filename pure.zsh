# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# git:
# %b => current branch
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


# turns seconds into human readable time
# 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_pure_human_time_to_var() {
	local human total_seconds=$1 var=$2
	local days=$(( total_seconds / 60 / 60 / 24 ))
	local hours=$(( total_seconds / 60 / 60 % 24 ))
	local minutes=$(( total_seconds / 60 % 60 ))
	local seconds=$(( total_seconds % 60 ))
	(( days > 0 )) && human+="${days}d "
	(( hours > 0 )) && human+="${hours}h "
	(( minutes > 0 )) && human+="${minutes}m "
	human+="${seconds}s"

	# store human readable time in variable as specified by caller
	typeset -g "${var}"="${human}"
}

# stores (into prompt_pure_cmd_exec_time) the exec time of the last command if set threshold was exceeded
prompt_pure_check_cmd_exec_time() {
	integer elapsed
	(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
	typeset -g prompt_pure_cmd_exec_time=
	(( elapsed > ${PURE_CMD_MAX_EXEC_TIME:-5} )) && {
		prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
	}
}

prompt_pure_set_title() {
	# emacs terminal does not support settings the title
	(( ${+EMACS} )) && return

	# tell the terminal we are setting the title
	print -n '\e]0;'
	# show hostname if connected through ssh
	[[ -n $SSH_CONNECTION ]] && print -Pn '(%m) '
	case $1 in
		expand-prompt)
			print -Pn $2;;
		ignore-escape)
			print -rn $2;;
	esac
	# end set title
	print -n '\a'
}

prompt_pure_preexec() {
	if [[ -n $prompt_pure_git_fetch_pattern ]]; then
		# detect when git is performing pull/fetch (including git aliases).
		local -H MATCH MBEGIN MEND match mbegin mend
		if [[ $2 =~ (git|hub)\ (.*\ )?($prompt_pure_git_fetch_pattern)(\ .*)?$ ]]; then
			# we must flush the async jobs to cancel our git fetch in order
			# to avoid conflicts with the user issued pull / fetch.
			async_flush_jobs 'prompt_pure'
		fi
	fi

	typeset -g prompt_pure_cmd_timestamp=$EPOCHSECONDS

	# shows the current dir and executed command in the title while a process is active
	prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"
}

# string length ignoring ansi escapes
prompt_pure_string_length_to_var() {
	local str=$1 var=$2 length
	# perform expansion on str and check length
	length=$(( ${#${(S%%)str//(\%([KF1]|)\{*\}|\%[Bbkf])}} ))

	# store string length in variable as specified by caller
	typeset -g "${var}"="${length}"
}

prompt_pure_preprompt_render() {
	setopt localoptions noshwordsplit

	# Set color for git branch/dirty status, change color if dirty checking has
	# been delayed.
	local git_color=242
	[[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && git_color=red

	# Initialize the preprompt arrays.
	local -a preprompt_parts
	local -a rpreprompt_parts
	local space_between_preprompts

	# Set the path.
	preprompt_parts+=('%F{blue}%~%f')

	# Add git branch and dirty status info.
	typeset -gA prompt_pure_vcs_info
	if [[ -n $prompt_pure_vcs_info[branch] ]]; then
		preprompt_parts+=("%F{$git_color}"'${prompt_pure_vcs_info[branch]}${prompt_pure_git_dirty}%f')
	fi
	# Git pull/push arrows.
	if [[ -n $prompt_pure_git_arrows ]]; then
		preprompt_parts+=('%F{cyan}${prompt_pure_git_arrows}%f')
	fi

	# Username and machine, if applicable.
	[[ -n $prompt_pure_username ]] && preprompt_parts+=('$prompt_pure_username')
	# Execution time.
	[[ -n $prompt_pure_cmd_exec_time ]] && preprompt_parts+=('%F{yellow}${prompt_pure_cmd_exec_time}%f')

	# NodeJS version
	[[ -n $prompt_pure_node_version ]] && rpreprompt_parts+=('%F{green}${prompt_pure_node_version}%f')
	# Ruby version
	[[ -n $prompt_pure_ruby_version ]] && rpreprompt_parts+=('%F{197}${prompt_pure_ruby_version}%f')
	# AWS profile
	[[ -n $prompt_pure_aws_profile ]] && rpreprompt_parts+=('%F{214}${prompt_pure_aws_profile}%f')

	local cleaned_ps1=$PROMPT
	local -H MATCH MBEGIN MEND
	if [[ $PROMPT = *$prompt_newline* ]]; then
		# When the prompt contains newlines, we keep everything before the first
		# and after the last newline, leaving us with everything except the
		# preprompt. This is needed because some software prefixes the prompt
		# (e.g. virtualenv).
		cleaned_ps1=${PROMPT%%${prompt_newline}*}${PROMPT##*${prompt_newline}}
	fi
	unset MATCH MBEGIN MEND

	# Space between left and right preprompts
	integer preprompt_left_length preprompt_right_length space_length
	prompt_pure_string_length_to_var "${(j. .)preprompt_parts}" "preprompt_left_length"
	prompt_pure_string_length_to_var "${(j. .)rpreprompt_parts}" "preprompt_right_length"
	(( space_length = COLUMNS - preprompt_left_length - preprompt_right_length - 1))

	space_between_preprompts="$(printf %${space_length}s)"

	# Construct the new prompt with a clean preprompt.
	local -ah ps1
	ps1=(
		$prompt_newline           # Initial newline, for spaciousness.
		${(j. .)preprompt_parts}  # Join left parts, space separated.
		$space_between_preprompts # Separate preprompts.
		${(j. .)rpreprompt_parts} # Join right parts, space separated.
		$prompt_newline           # Separate preprompt and prompt.
		$cleaned_ps1
	)

	PROMPT="${(j..)ps1}"

	# Expand the prompt for future comparision.
	local expanded_prompt
	expanded_prompt="${(S%%)PROMPT}"

	if [[ $1 != precmd ]] && [[ $prompt_pure_last_prompt != $expanded_prompt ]]; then
		# Redraw the prompt.
		zle && zle .reset-prompt
	fi

	typeset -g prompt_pure_last_prompt=$expanded_prompt
}

prompt_pure_precmd() {
	# check exec time and store it in a variable
	prompt_pure_check_cmd_exec_time
	unset prompt_pure_cmd_timestamp

	# shows the full path in the title
	prompt_pure_set_title 'expand-prompt' '%~'

	# preform async git dirty check and fetch
	prompt_pure_async_tasks

	# store name of virtualenv in psvar if activated
	psvar[12]=
	[[ -n $VIRTUAL_ENV ]] && psvar[12]="${VIRTUAL_ENV:t}"

	# print the preprompt
	prompt_pure_preprompt_render "precmd"
}

prompt_pure_async_node() {
	setopt localoptions noshwordsplit extendedglob
	builtin cd -q $1

	# Always hide
	[[ ${PURE_NODE_HIDE:-false} == true ]] && return
	# Always show or found some Node artifacts
	[[ ${PURE_NODE_SHOW:-false} == true ]] || [[ -f '.node-version' || -f '.nvmrc' || -f 'package.json' || -d 'node_modules' || -n *.js(#qN^/) ]] || return

	command node -v | cut -c2-
}

prompt_pure_async_ruby() {
	setopt localoptions noshwordsplit extendedglob
	builtin cd -q $1

	# Always hide
	[[ ${PURE_RUBY_HIDE:-false} == true ]] && return
	# Always show or found some Ruby files
	[[ ${PURE_RUBY_SHOW:-false} == true ]] || [[ -f '.ruby-version' || -f 'Gemfile' || -f 'Rakefile' || -f 'Capfile' || -n *.rb(#qN^/) ]] || return

	command ruby -v | awk '{ print $2 }'
}

prompt_pure_async_aws() {
	setopt localoptions noshwordsplit
	local aws_profile=$(echo $1 | awk -F '=' '{ print $2 }')
	# Always hide
	[[ ${PURE_AWS_HIDE:-false} == true ]] && return
	# Always show or AWS_PROFILE is set
	[[ ${PURE_AWS_SHOW:-false} == true ]] || [[ -n $aws_profile ]] || return

	output=$(aws configure list --profile "$aws_profile")
	profile=$(echo $output | grep profile | awk -F '[[:space:]][[:space:]]+' '{ print $3 }')
	region=$(echo $output | grep region | awk -F '[[:space:]][[:space:]]+' '{ print $3 }')

	if [[ ${PURE_AWS_REGION_SHOW:-true} == true ]] && [[ -n ${region//<not set>/} ]]; then
		print "${profile} in ${region}"
	elif [[ $profile == '<not set>' ]]; then
		print 'default'
	else
		print $profile
	fi
}

prompt_pure_async_git_aliases() {
	setopt localoptions noshwordsplit
	local dir=$1
	local -a gitalias pullalias

	# we enter repo to get local aliases as well.
	builtin cd -q $dir

	# list all aliases and split on newline.
	gitalias=(${(@f)"$(command git config --get-regexp "^alias\.")"})
	for line in $gitalias; do
		parts=(${(@)=line})           # split line on spaces
		aliasname=${parts[1]#alias.}  # grab the name (alias.[name])
		shift parts                   # remove aliasname

		# check alias for pull or fetch (must be exact match).
		if [[ $parts =~ ^(.*\ )?(pull|fetch)(\ .*)?$ ]]; then
			pullalias+=($aliasname)
		fi
	done

	print -- ${(j:|:)pullalias}  # join on pipe (for use in regex).
}

prompt_pure_async_vcs_info() {
	setopt localoptions noshwordsplit
	builtin cd -q $1 2>/dev/null

	# configure vcs_info inside async task, this frees up vcs_info
	# to be used or configured as the user pleases.
	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' use-simple true
	# only export two msg variables from vcs_info
	zstyle ':vcs_info:*' max-exports 2
	# export branch (%b) and git toplevel (%R)
	zstyle ':vcs_info:git*' formats '%b' '%R'
	zstyle ':vcs_info:git*' actionformats '%b|%a' '%R'

	vcs_info

	local -A info
	info[top]=$vcs_info_msg_1_
	info[branch]=$vcs_info_msg_0_

	print -r - ${(@kvq)info}
}

# fastest possible way to check if repo is dirty
prompt_pure_async_git_dirty() {
	setopt localoptions noshwordsplit
	local untracked_dirty=$1 dir=$2

	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q $dir

	if [[ $untracked_dirty = 0 ]]; then
		command git diff --no-ext-diff --quiet --exit-code
	else
		test -z "$(command git status --porcelain --ignore-submodules -unormal)"
	fi

	return $?
}

prompt_pure_async_git_fetch() {
	setopt localoptions noshwordsplit
	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q $1

	# set GIT_TERMINAL_PROMPT=0 to disable auth prompting for git fetch (git 2.3+)
	export GIT_TERMINAL_PROMPT=0
	# set ssh BachMode to disable all interactive ssh password prompting
	export GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o BatchMode=yes"}

	command git -c gc.auto=0 fetch &>/dev/null || return 99

	# check arrow status after a successful git fetch
	prompt_pure_async_git_arrows $1
}

prompt_pure_async_git_arrows() {
	setopt localoptions noshwordsplit
	builtin cd -q $1
	command git rev-list --left-right --count HEAD...@'{u}'
}

prompt_pure_async_tasks() {
	setopt localoptions noshwordsplit

	# initialize async worker
	((!${prompt_pure_async_init:-0})) && {
		async_start_worker "prompt_pure" -u -n
		async_register_callback "prompt_pure" prompt_pure_async_callback
		typeset -g prompt_pure_async_init=1
	}

	typeset -gA prompt_pure_vcs_info

	local -H MATCH MBEGIN MEND
	if ! [[ $PWD = ${prompt_pure_vcs_info[pwd]}* ]]; then
		# stop any running async jobs
		async_flush_jobs "prompt_pure"

		# reset git preprompt variables, switching working tree
		unset prompt_pure_git_dirty
		unset prompt_pure_git_last_dirty_check_timestamp
		unset prompt_pure_git_arrows
		unset prompt_pure_git_fetch_pattern
		prompt_pure_vcs_info[branch]=
		prompt_pure_vcs_info[top]=
	fi
	unset MATCH MBEGIN MEND

	# Versions
	async_job "prompt_pure" prompt_pure_async_node $PWD
	async_job "prompt_pure" prompt_pure_async_ruby $PWD
	async_job "prompt_pure" prompt_pure_async_aws $(env | grep AWS_PROFILE)

	async_job "prompt_pure" prompt_pure_async_vcs_info $PWD

	# # only perform tasks inside git working tree
	[[ -n $prompt_pure_vcs_info[top] ]] || return

	prompt_pure_async_refresh
}

prompt_pure_async_refresh() {
	setopt localoptions noshwordsplit

	if [[ -z $prompt_pure_git_fetch_pattern ]]; then
		# we set the pattern here to avoid redoing the pattern check until the
		# working three has changed. pull and fetch are always valid patterns.
		typeset -g prompt_pure_git_fetch_pattern="pull|fetch"
		async_job "prompt_pure" prompt_pure_async_git_aliases $working_tree
	fi

	async_job "prompt_pure" prompt_pure_async_git_arrows $PWD

	# do not preform git fetch if it is disabled or working_tree == HOME
	if (( ${PURE_GIT_PULL:-1} )) && [[ $working_tree != $HOME ]]; then
		# tell worker to do a git fetch
		async_job "prompt_pure" prompt_pure_async_git_fetch $PWD
	fi

	# if dirty checking is sufficiently fast, tell worker to check it again, or wait for timeout
	integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_pure_git_last_dirty_check_timestamp:-0} ))
	if (( time_since_last_dirty_check > ${PURE_GIT_DELAY_DIRTY_CHECK:-1800} )); then
		unset prompt_pure_git_last_dirty_check_timestamp
		# check check if there is anything to pull
		async_job "prompt_pure" prompt_pure_async_git_dirty ${PURE_GIT_UNTRACKED_DIRTY:-1} $PWD
	fi
}

prompt_pure_check_git_arrows() {
	setopt localoptions noshwordsplit
	local arrows left=${1:-0} right=${2:-0}

	(( right > 0 )) && arrows+=${PURE_GIT_DOWN_ARROW:-⇣}
	(( left > 0 )) && arrows+=${PURE_GIT_UP_ARROW:-⇡}

	[[ -n $arrows ]] || return
	typeset -g REPLY=$arrows
}

prompt_pure_async_callback() {
	setopt localoptions noshwordsplit
	local job=$1 code=$2 output=$3 exec_time=$4 next_pending=$6
	local do_render=0

	case $job in
		prompt_pure_async_vcs_info)
			local -A info
			typeset -gA prompt_pure_vcs_info

			# parse output (z) and unquote as array (Q@)
			info=("${(Q@)${(z)output}}")
			local -H MATCH MBEGIN MEND
			# check if git toplevel has changed
			if [[ $info[top] = $prompt_pure_vcs_info[top] ]]; then
				# if stored pwd is part of $PWD, $PWD is shorter and likelier
				# to be toplevel, so we update pwd
				if [[ $prompt_pure_vcs_info[pwd] = ${PWD}* ]]; then
					prompt_pure_vcs_info[pwd]=$PWD
				fi
			else
				# store $PWD to detect if we (maybe) left the git path
				prompt_pure_vcs_info[pwd]=$PWD
			fi
			unset MATCH MBEGIN MEND

			# update has a git toplevel set which means we just entered a new
			# git directory, run the async refresh tasks
			[[ -n $info[top] ]] && [[ -z $prompt_pure_vcs_info[top] ]] && prompt_pure_async_refresh

			# always update branch and toplevel
			prompt_pure_vcs_info[branch]=$info[branch]
			prompt_pure_vcs_info[top]=$info[top]

			do_render=1
			;;
		prompt_pure_async_git_aliases)
			if [[ -n $output ]]; then
				# append custom git aliases to the predefined ones.
				prompt_pure_git_fetch_pattern+="|$output"
			fi
			;;
		prompt_pure_async_git_dirty)
			local prev_dirty=$prompt_pure_git_dirty
			if (( code == 0 )); then
				unset prompt_pure_git_dirty
			else
				typeset -g prompt_pure_git_dirty="*"
			fi

			[[ $prev_dirty != $prompt_pure_git_dirty ]] && do_render=1

			# When prompt_pure_git_last_dirty_check_timestamp is set, the git info is displayed in a different color.
			# To distinguish between a "fresh" and a "cached" result, the preprompt is rendered before setting this
			# variable. Thus, only upon next rendering of the preprompt will the result appear in a different color.
			(( $exec_time > 5 )) && prompt_pure_git_last_dirty_check_timestamp=$EPOCHSECONDS
			;;
		prompt_pure_async_git_fetch|prompt_pure_async_git_arrows)
			# prompt_pure_async_git_fetch executes prompt_pure_async_git_arrows
			# after a successful fetch.
			if (( code == 0 )); then
				local REPLY
				prompt_pure_check_git_arrows ${(ps:\t:)output}
				if [[ $prompt_pure_git_arrows != $REPLY ]]; then
					typeset -g prompt_pure_git_arrows=$REPLY
					do_render=1
				fi
			elif (( code != 99 )); then
				# Unless the exit code is 99, prompt_pure_async_git_arrows
				# failed with a non-zero exit status, meaning there is no
				# upstream configured.
				if [[ -n $prompt_pure_git_arrows ]]; then
					unset prompt_pure_git_arrows
					do_render=1
				fi
			fi
			;;
		prompt_pure_async_node)
			local prev_version=$prompt_pure_node_version
			if [[ -n $output ]]; then
				typeset -g prompt_pure_node_version="${PURE_NODE_SYMBOL:-⬢} $output"
			else
				unset prompt_pure_node_version
			fi
			[[ $prev_version != $prompt_pure_node_version ]] && do_render=1
			;;
		prompt_pure_async_ruby)
			local prev_version=$prompt_pure_ruby_version
			if [[ -n $output ]]; then
				typeset -g prompt_pure_ruby_version="${PURE_RUBY_SYMBOL:-⬥} $output"
			else
				unset prompt_pure_ruby_version
			fi
			[[ $prev_version != $prompt_pure_ruby_version ]] && do_render=1
			;;
		prompt_pure_async_aws)
			local prev_profile=$prompt_pure_aws_profile
			if [[ -n $output ]]; then
				typeset -g prompt_pure_aws_profile="${PURE_AWS_SYMBOL:-☁} $output"
			else
				unset prompt_pure_aws_profile
			fi
			[[ $prev_profile != $prompt_pure_aws_profile ]] && do_render=1
			;;
	esac

	if (( next_pending )); then
		(( do_render )) && typeset -g prompt_pure_async_render_requested=1
		return
	fi

	[[ ${prompt_pure_async_render_requested:-$do_render} = 1 ]] && prompt_pure_preprompt_render
	unset prompt_pure_async_render_requested
}

prompt_pure_setup() {
	# Prevent percentage showing up if output doesn't end with a newline.
	export PROMPT_EOL_MARK=''

	# disallow python virtualenvs from updating the prompt
	export VIRTUAL_ENV_DISABLE_PROMPT=1

	prompt_opts=(subst percent)

	# borrowed from promptinit, sets the prompt options in case pure was not
	# initialized via promptinit.
	setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"

	if [[ -z $prompt_newline ]]; then
		# This variable needs to be set, usually set by promptinit.
		typeset -g prompt_newline=$'\n%{\r%}'
	fi

	zmodload zsh/datetime
	zmodload zsh/zle
	zmodload zsh/parameter

	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	autoload -Uz async && async

	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec

	# show username@host if logged in through SSH
	[[ "$SSH_CONNECTION" != '' ]] && prompt_pure_username='%F{242}%n@%m%f'

	# show username@host if root, with username in white
	[[ $UID -eq 0 ]] && prompt_pure_username='%F{white}%n%f%F{242}@%m%f'

	# if a virtualenv is activated, display it in grey
	PROMPT='%(12V.%F{242}%12v%f .)'

	# prompt turns red if the previous command didn't exit with 0
	PROMPT+='%(?.%F{magenta}.%F{red})${PURE_PROMPT_SYMBOL:-❯}%f '
}

prompt_pure_setup "$@"
