import { Link } from 'react-router-dom';
import { HiPlus } from 'react-icons/hi';

function Navbar() {
  return (
    <nav className="navbar">
      <div className="navbar-inner">
        <Link to="/" className="navbar-logo">
          <span>⚡</span> PulseLog <small style={{fontSize: '0.5em', opacity: 0.7}}>v2.0</small>
        </Link>
        <div className="navbar-actions">
          <Link to="/create" className="btn btn-primary">
            <HiPlus size={18} />
            <span>New Post</span>
          </Link>
        </div>
      </div>
    </nav>
  );
}

export default Navbar;
