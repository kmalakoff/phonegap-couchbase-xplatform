function(doc) {
  if(doc.type == "data"){
    emit(doc._id, doc.message);
  }
}
