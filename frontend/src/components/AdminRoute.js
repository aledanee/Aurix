import React from 'react';
import { Navigate } from 'react-router-dom';
import useAuth from '../hooks/useAuth';
import PrivateRoute from './PrivateRoute';

export default function AdminRoute({ children }) {
  const { isAdmin } = useAuth();

  return (
    <PrivateRoute>
      {isAdmin ? children : <Navigate to="/" replace />}
    </PrivateRoute>
  );
}
