---
name: tmux
description: 获取tmux其它pane的屏幕输出、向tmux其它pane发送keys。可以用此技能操作运行在tmux pane中的TUI程序（如gdb）
---

# Tmux获取其它pane的屏幕输出

使用
```bash
tmux capture-pane -t %paneid -p
```
获取屏幕输出

# Tmux向其它pane发送keys

使用heredoc语法，避免直接在bash上执行tmux send-keys命令存在复杂的转义问题。

```bash
cat <<'EOF' | tmux load-buffer -
create table bar(
  id int,
  name text
);
EOF

tmux paste-buffer -t %paneid
tmux send-keys -t %paneid Enter
```

