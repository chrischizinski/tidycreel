# 🧠 Codex CLI Instructions  
### Build a Local Scientific Knowledge-Base Assistant Using Claude + RAG

## 📌 Project Goal

Build a **local Python CLI tool** that allows me to:

- **Ingest** 20–30 scientific **PDF and Markdown files** into a lightweight **knowledge base**.
- **Query** those documents using **Claude** (via an OpenAI-compatible endpoint).
- Use **retrieval-augmented generation (RAG)** so Claude answers *only* from the papers.
- Produce:
  - **Accurate scientific explanations**
  - **Inline citations** to filenames/pages
  - **R code** and **R package design suggestions** when relevant

The CLI should support exactly **two workflows**:

1. `codex ingest` – build/update the local knowledge base  
2. `codex ask "<question>"` – query the knowledge base with Claude  

---

## 🛠️ Tech Stack and Requirements

- **Python 3.11+**
- Libraries:
  - `langchain`
  - `langchain-community`
  - `langchain-text-splitters`
  - `chromadb`
  - `pypdf`
  - `langchain-openai`  
- Claude is accessed through an **OpenAI-compatible API endpoint**
  - Must use environment variables:
    - `OPENAI_API_KEY`
    - `OPENAI_BASE_URL` (if required)

Embeddings and LLM should both use the same API endpoint, so the system can later swap in other embedding models.

---

## 📁 Project Structure

Create a Python project with the following layout:

```
kb_assistant/
  pyproject.toml      # or requirements.txt
  kb_assistant/
    __init__.py
    config.py
    ingest_docs.py
    query_kb.py
    cli.py
  README.md
```

---

## ⚙️ `config.py`

Define constants and environment handling:

- `DATA_DIR = "data"` – directory where PDFs/MDs are stored
- `DB_DIR = "chroma_db"` – persistent Chroma directory
- `EMBEDDING_MODEL` – e.g., `"text-embedding-3-large"` or custom
- `LLM_MODEL` – e.g., `"claude-3-5-sonnet"` via OpenAI-compatible API

Environment variable requirements:

```text
OPENAI_API_KEY must be set.
OPENAI_BASE_URL optional but supported.
```

Raise a clear error if missing.

---

## 📥 `ingest_docs.py`

Implement:

```python
def ingest_documents(
    data_dir: str | Path = DATA_DIR,
    db_dir: str | Path = DB_DIR,
) -> None:
    ...
```

### Required behavior

1. **Walk the data directory** recursively.
2. For each file:
   - `.pdf` → load with `PyPDFLoader`
   - `.md`, `.txt` → load with `TextLoader`
   - ignore everything else
3. For all loaded documents:
   - Add metadata:
     - `source_file` (str)
     - `page` (if provided by `PyPDFLoader`)
4. **Chunk using `RecursiveCharacterTextSplitter`:**
   - `chunk_size = 1200`
   - `chunk_overlap = 200`
   - `separators = ["\n\n", "\n", ".", " ", ""]`
5. **Embed using `OpenAIEmbeddings`**
   - Configured to use Claude’s embedding endpoint via OpenAI-compatible API
6. **Persist to Chroma** at `db_dir`:
   - Use `Chroma.from_documents(...)`
7. Print summary logs:
   - Number of documents loaded
   - Number of chunks created
   - Vector store path

---

## 🔍 `query_kb.py`

Implement a function:

```python
def ask_knowledge_base(question: str, k: int = 8) -> str:
    ...
```

### Required behavior

1. Load Chroma from `DB_DIR` with the same embedding model.
2. Retrieve top-`k` chunks using vector similarity search.
3. Build a context block:

```
[source_file.pdf, p.3]
<chunk text>

[source_file2.md]
<chunk text>
```

4. Construct the prompt:

**System message must include:**

- “Use ONLY the provided context for factual claims.”
- “Cite your sources with `[filename, p.X]`.”
- “If something is not in the context, say so.”
- “When appropriate, provide R code using tidyverse style.”
- “Propose R package structures when the question involves workflow design.”

**User message must include:**

- Original question
- Context block
- Instructions to avoid fabricating citations

5. Call Claude using `ChatOpenAI` (OpenAI-compatible API).

6. Return Claude’s response text.

---

## 🧰 `cli.py`

Create a simple `typer` or `argparse` CLI with commands:

### `codex ingest`

- Runs the ingestion pipeline  
- Example:

```
codex ingest --data ./data
```

### `codex ask "<question>"`

- Queries Claude with RAG  
- Example:

```
codex ask "How do these papers model detection probability in creel surveys?"
```

Bundled results should:

- Show answer  
- Show sources used  
- Indicate any missing contextual information  

---

## 📄 README.md

Include:

- Setup instructions  
- Example usage  
- Environment variable configuration  
- How to add new PDFs/Markdown files  
- Notes on chunking, retrieval quality, and citation format  

---

## ✔️ Deliverables Codex Should Produce

Codex should generate:

1. Full project folder with the structure above  
2. Working ingestion script  
3. Working query script  
4. A CLI interface with `ingest` and `ask` commands  
5. Prompts engineered for scientific + R development workflows  
6. Clean, well-commented Python code  
