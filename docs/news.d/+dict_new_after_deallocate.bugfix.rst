Fixed ``new_dict`` crashing after ``deallocate`` of a dict that had grown beyond one bucket, caused by recycled pointers being longer than requested.
