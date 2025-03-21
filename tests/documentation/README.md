# LLM to Review README.mds


# 1. Define list of READMEs to review

```
python3 find_readme.py --dir ~/Projects/forked/GenAIComps > readme_list.txt
# Please review this list that you'd like to review


```

# 2. Define LLM variables

```
export LLM_MODEL_ID="google/gemini-2.0-pro-exp-02-05:free"
export LLM_ENDPOINT=""  # e.g. https://openrouter.ai/api 
export OPENAI_API_KEY="" # key associated with LLM_ENDPOINT
```

# 3. Spin up OPEA Textgen service

```
source start_doc_checking_llm.sh
```

# 4. Execute README Review Script

```
source review_readme.sh readme_list.txt
```