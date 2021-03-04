graph LR
  subgraph init ["Current state"]
    a1["Apple [1]"]
    a2["Banana [2]"]
    a3["Orange [3]"]
  end
  subgraph fake ["Fake record"]
    b1["Apple [1]"]
    b2["Banana [2]"]
    x1["fake [3]"]
    style x1 stroke:gray,fill:silver
    b3["Orange [3]"]
  end
  a1 --> b1
  a2 --> b2
  a3 --> b3
  subgraph ordered ["Ordering SQL"]
    c1["Apple [1]"]
    c2["Banana [2]"]
    x2["fake [3]"]
    style x2 stroke:gray,fill:silver
    c3["Orange [4]"]
  end
  b1 --> c1
  b2 --> c2
  b3 --> c3
  subgraph insert_at ["After `insert_at`"]
    d1["Apple [1]"]
    d2["Banana [2]"]
    d3["Orange [4]"]
  end
  c1 --> d1
  c2 --> d2
  c3 --> d3
    subgraph repo_insert ["Repo.insert"]
    e1["Apple [1]"]
    e2["Banana [2]"]
    x3["Watermelon [3]"]
    style x3 stroke:green,fill:lightgreen
    e3["Orange [4]"]
  end
  d1 --> e1
  d2 --> e2
  d3 --> e3

