// In-memory stand-in for the slice of the firebase-admin Firestore API the
// migration scripts use. Synthetic data only; no network, no emulator.

export const DELETE = Symbol("FieldValue.delete");
export const SERVER_TIMESTAMP = Symbol("FieldValue.serverTimestamp");
export const DOCUMENT_ID = Symbol("FieldPath.documentId");

export const FakeFieldValue = Object.freeze({
  delete: () => DELETE,
  serverTimestamp: () => SERVER_TIMESTAMP,
});

class Version {
  constructor(n) {
    this.n = n;
  }
  isEqual(other) {
    return other instanceof Version && other.n === this.n;
  }
}

const grpcError = (code) => Object.assign(new Error(`synthetic grpc ${code}`), { code });

export class FakeDb {
  constructor(seed = {}) {
    this.docs = new Map();
    this.clock = 0;
    this.writes = [];
    this.deletes = 0;
    /** Optional hook(path) run just before a write is applied. */
    this.beforeWrite = null;
    for (const [path, data] of Object.entries(seed)) this.put(path, data);
  }

  put(path, data) {
    this.docs.set(path, { data: structuredClone(data), version: new Version(++this.clock) });
  }

  dump() {
    return Object.fromEntries([...this.docs].map(([path, entry]) => [path, structuredClone(entry.data)]));
  }

  collection(name) {
    return new FakeQuery(this, name);
  }

  /** Distinct collection ids directly under [parentPath] ("" = root). */
  collectionIdsUnder(parentPath) {
    const prefix = parentPath ? `${parentPath}/` : "";
    const ids = new Set();
    for (const path of this.docs.keys()) {
      if (!path.startsWith(prefix)) continue;
      const rest = path.slice(prefix.length).split("/");
      if (rest.length >= 2) ids.add(rest[0]);
    }
    return [...ids].sort().map((id) => ({ id }));
  }

  async listCollections() {
    return this.collectionIdsUnder("");
  }

  snapshot(path) {
    const entry = this.docs.get(path);
    const id = path.split("/").pop();
    return {
      id,
      exists: entry !== undefined,
      ref: new FakeRef(this, path),
      updateTime: entry?.version,
      data: () => (entry ? structuredClone(entry.data) : undefined),
    };
  }
}

class FakeQuery {
  constructor(db, name, opts = { limit: Infinity, after: null, ordered: false }) {
    this.db = db;
    this.name = name;
    this.opts = opts;
  }
  doc(id) {
    return new FakeRef(this.db, `${this.name}/${id}`);
  }
  orderBy(field) {
    if (field !== DOCUMENT_ID) throw new Error("fake supports documentId ordering only");
    return new FakeQuery(this.db, this.name, { ...this.opts, ordered: true });
  }
  limit(n) {
    return new FakeQuery(this.db, this.name, { ...this.opts, limit: n });
  }
  startAfter(snapshot) {
    return new FakeQuery(this.db, this.name, { ...this.opts, after: snapshot.id });
  }
  async get() {
    if (!this.opts.ordered) throw new Error("migrations must page in documentId order");
    const prefix = `${this.name}/`;
    const ids = [...this.db.docs.keys()]
      .filter((p) => p.startsWith(prefix) && !p.slice(prefix.length).includes("/"))
      .map((p) => p.slice(prefix.length))
      .sort()
      .filter((id) => this.opts.after === null || id > this.opts.after)
      .slice(0, this.opts.limit);
    return { docs: ids.map((id) => this.db.snapshot(prefix + id)) };
  }
}

class FakeRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").pop();
  }
  async get() {
    return this.db.snapshot(this.path);
  }
  async listCollections() {
    return this.db.collectionIdsUnder(this.path);
  }
  async create(data) {
    this.db.beforeWrite?.(this.path);
    if (this.db.docs.has(this.path)) throw grpcError(6);
    this.db.writes.push({ op: "create", path: this.path, keys: Object.keys(data).sort() });
    this.db.put(this.path, resolveFields({}, data));
  }
  async update(fields, precondition) {
    this.db.beforeWrite?.(this.path);
    const entry = this.db.docs.get(this.path);
    if (!entry) throw grpcError(5);
    if (precondition?.lastUpdateTime && !precondition.lastUpdateTime.isEqual(entry.version)) {
      throw grpcError(9);
    }
    this.db.writes.push({ op: "update", path: this.path, keys: Object.keys(fields).sort() });
    this.db.put(this.path, resolveFields(entry.data, fields));
  }
  async delete() {
    this.db.deletes += 1;
    throw new Error("migrations must never delete documents");
  }
}

function resolveFields(base, fields) {
  const next = structuredClone(base);
  for (const [key, value] of Object.entries(fields)) {
    if (value === DELETE) delete next[key];
    else if (value === SERVER_TIMESTAMP) next[key] = "<serverTimestamp>";
    else next[key] = value;
  }
  return next;
}
