#!/bin/bash

# 作業ディレクトリ
WORKING_DIR="/tmp/ip_checker"

# ファイル保存先
SAVE_FILE_NAME="ip.txt"

# ログ保存先
LOG_FILE_NAME="ip.log"

# エラー上限
ERROR_THRESHOLD=5

# url チェック先
URLS=("inet-ip.info" "ipcheck.ieserver.net")

# ip 取得
function get_ip() {
  curl -Ss -f "$1"
}

# 保存
function save() {
  : > "$WORKING_DIR/$SAVE_FILE_NAME"
  for line in "$@"
    do
      echo "$line" >> "$WORKING_DIR/$SAVE_FILE_NAME"
    done
}

# ログ
function log() {
  : > "$WORKING_DIR/$LOG_FILE_NAME"
  for line in "$@"
    do
      echo "$line" >> "$WORKING_DIR/$LOG_FILE_NAME"
    done
}

# 投稿
function post() {
  # 一行にする
  for line in "$@"
    do
      text="${text}\n$line"
    done

  # slack への投稿
  ## SLACK_WEBHOOK_URL は環境変数にて設定されていること
  curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$text\"}" "$SLACK_WEBHOOK_URL"
}

# 通知
function notify() {
  # TODO: implement
  for line in "$@"
    do
      echo "[notify] $line"
    done
}

# 初期化
if [ ! -e "$WORKING_DIR" ]; then
  # 作業ディレクトリ作成
  mkdir "$WORKING_DIR"
fi
if [ ! -e "$WORKING_DIR/$SAVE_FILE_NAME" ]; then
  # 初期 ip 書き込み
  save "0.0.0.0" "0"
fi

# 過去の ip 取得
LAST_IP=$(sed -n 1p "$WORKING_DIR/$SAVE_FILE_NAME")

# エラー回数
error_times=$(sed -n 2p "$WORKING_DIR/$SAVE_FILE_NAME")

# 実行
for url in "${URLS[@]}"
  # 現在の ip を取得
  do
    current_ip=$(get_ip "$url")
    if [ $? != 0 ] || [ -z "$current_ip" ]; then
      current_ip="fail"
    else
      break
    fi
  done

  # 過去の ip と比較
  if [ $LAST_IP = "0.0.0.0" ]; then
    ## 初回起動
    if [ "$current_ip" = "fail" ]; then
      ### 取得失敗 -> 投稿
      messages=("[Failed] IPアドレスの取得に失敗しました")
      post "${messages[@]}"

      if [ $? != 0 ]; then
        #### 投稿失敗 -> 通知
        messages=("[Failed] IPアドレスの取得に失敗しました" "[Failed] 投稿に失敗しました")
        notify "${messages[@]}"
      fi
    else
      ### 取得成功 -> 投稿
      messages=("IPアドレスの監視を開始しました" "現在のIP=$current_ip")
      post "${messages[@]}"

      if [ $? != 0 ]; then
        #### 投稿失敗 -> 通知
        messages=("IPアドレスの監視を開始しました" "現在のIP=$current_ip" "[Failed] 投稿に失敗しました")
        notify "${messages[@]}"
      fi

      ### 保存
      save "$current_ip" "0"
    fi
  elif [ "$current_ip" = "fail" ]; then
    ## 取得失敗
    ((error_times++))

    if [ "$error_times" -ge "$ERROR_THRESHOLD" ]; then
      ### エラー上限 -> 投稿
      messages=("[Failed] IPアドレスの取得に${error_times}回続けて失敗しました")
      post "${messages[@]}"

      if [ $? != 0 ]; then
        #### 投稿失敗 -> 通知
        messages=("[Failed] IPアドレスの取得に${error_times}回続けて失敗しました" "[Failed] 投稿に失敗しました")
        notify "${messages[@]}"
      fi
      ### 保存
      save "$LAST_IP" "0"
    else
      ### 保存
      save "$LAST_IP" "$error_times"
    fi
  elif [ "$current_ip" != "$LAST_IP" ]; then
    ## ip 変更あり -> 投稿
    messages=("IPアドレスが変更されています" "現在のIP=$current_ip <- 前回のIP=$LAST_IP")
    post "${messages[@]}"

    if [ $? != 0 ]; then
      ### 投稿失敗 -> 通知
      messages=("IPアドレスが変更されています" "現在のIP=$current_ip <- 前回のIP=$LAST_IP" "[Failed] 投稿に失敗しました")
      notify post "${messages[@]}"
    fi
    ## 保存
    save "$current_ip" "0"
  else
    ## 保存
    save "$current_ip" "0"
  fi